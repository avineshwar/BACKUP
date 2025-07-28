#!/usr/bin/env python3
"""
Unit tests for confluence_sync.py
"""

import unittest
from unittest.mock import Mock, patch, MagicMock
import tempfile
import shutil
from pathlib import Path
import os
import sys

# Add current directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from confluence_sync import clean_text, download_page, main


class TestCleanText(unittest.TestCase):
    """Test the clean_text function."""
    
    def test_empty_content(self):
        """Test with empty content."""
        self.assertEqual(clean_text(""), "")
        self.assertEqual(clean_text(None), "")
    
    def test_simple_html(self):
        """Test with simple HTML."""
        html = "<p>Hello world</p>"
        expected = "Hello world"
        self.assertEqual(clean_text(html), expected)
    
    def test_complex_html(self):
        """Test with complex HTML structure."""
        html = """
        <div>
            <h1>Title</h1>
            <p>Paragraph 1</p>
            <p>Paragraph 2</p>
            <ul>
                <li>Item 1</li>
                <li>Item 2</li>
            </ul>
        </div>
        """
        result = clean_text(html)
        self.assertIn("Title", result)
        self.assertIn("Paragraph 1", result)
        self.assertIn("Item 1", result)
    
    def test_whitespace_cleanup(self):
        """Test excessive whitespace removal."""
        html = "<p>Line 1</p>\n\n\n<p>Line 2</p>"
        result = clean_text(html)
        # Should not have triple newlines
        self.assertNotIn("\n\n\n", result)


class TestDownloadPage(unittest.TestCase):
    """Test the download_page function."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.temp_dir = Path(tempfile.mkdtemp())
        self.mock_confluence = Mock()
        self.page_id = "123456"
    
    def tearDown(self):
        """Clean up test fixtures."""
        shutil.rmtree(self.temp_dir)
    
    def test_download_page_success(self):
        """Test successful page download."""
        # Mock page data
        mock_page = {
            'title': 'Test Page',
            'body': {
                'storage': {
                    'value': '<p>Test content</p>'
                }
            }
        }
        
        # Mock attachments
        mock_attachments = {'results': []}
        
        # Configure mocks
        self.mock_confluence.get_page_by_id.return_value = mock_page
        self.mock_confluence.get_attachments_from_content.return_value = mock_attachments
        
        # Execute
        result = download_page(self.mock_confluence, self.page_id, self.temp_dir)
        
        # Verify
        self.assertIn("Downloaded: Test Page", result)
        
        # Check file creation
        page_dir = self.temp_dir / "Test Page"
        self.assertTrue(page_dir.exists())
        
        text_file = page_dir / "Test Page.txt"
        self.assertTrue(text_file.exists())
        
        content = text_file.read_text(encoding='utf-8')
        self.assertEqual(content, "Test content")
    
    def test_download_page_with_attachments(self):
        """Test page download with attachments."""
        # Mock page data
        mock_page = {
            'title': 'Page With Attachments',
            'body': {
                'storage': {
                    'value': '<p>Content with attachments</p>'
                }
            }
        }
        
        # Mock attachments
        mock_attachments = {
            'results': [
                {'id': 'att1', 'title': 'image.png'},
                {'id': 'att2', 'title': 'document.pdf'}
            ]
        }
        
        # Mock attachment data
        self.mock_confluence.get_attachment_by_id.side_effect = [
            b'fake_image_data',
            b'fake_pdf_data'
        ]
        
        # Configure mocks
        self.mock_confluence.get_page_by_id.return_value = mock_page
        self.mock_confluence.get_attachments_from_content.return_value = mock_attachments
        
        # Execute
        result = download_page(self.mock_confluence, self.page_id, self.temp_dir)
        
        # Verify
        self.assertIn("Downloaded: Page With Attachments", result)
        
        # Check attachment directory
        att_dir = self.temp_dir / "Page With Attachments" / "attachments"
        self.assertTrue(att_dir.exists())
        
        # Check attachment files
        self.assertTrue((att_dir / "image.png").exists())
        self.assertTrue((att_dir / "document.pdf").exists())
        
        # Verify attachment content
        self.assertEqual((att_dir / "image.png").read_bytes(), b'fake_image_data')
        self.assertEqual((att_dir / "document.pdf").read_bytes(), b'fake_pdf_data')
    
    def test_download_page_special_characters(self):
        """Test page with special characters in title."""
        # Mock page with special characters
        mock_page = {
            'title': 'Test/Page:With*Special?Characters',
            'body': {
                'storage': {
                    'value': '<p>Special content</p>'
                }
            }
        }
        
        mock_attachments = {'results': []}
        
        self.mock_confluence.get_page_by_id.return_value = mock_page
        self.mock_confluence.get_attachments_from_content.return_value = mock_attachments
        
        # Execute
        result = download_page(self.mock_confluence, self.page_id, self.temp_dir)
        
        # Verify title sanitization
        sanitized_title = "Test_Page_With_Special_Characters"
        self.assertIn(f"Downloaded: {sanitized_title}", result)
        
        # Check directory creation with sanitized name
        page_dir = self.temp_dir / sanitized_title
        self.assertTrue(page_dir.exists())
    
    def test_download_page_error_handling(self):
        """Test error handling in download_page."""
        # Configure mock to raise exception
        self.mock_confluence.get_page_by_id.side_effect = Exception("API Error")
        
        # Execute
        result = download_page(self.mock_confluence, self.page_id, self.temp_dir)
        
        # Verify error handling
        self.assertIn("Error:", result)
        self.assertIn("API Error", result)
    
    def test_download_page_empty_content(self):
        """Test page with empty or missing content."""
        # Mock page with no body content
        mock_page = {
            'title': 'Empty Page',
            'body': {}
        }
        
        mock_attachments = {'results': []}
        
        self.mock_confluence.get_page_by_id.return_value = mock_page
        self.mock_confluence.get_attachments_from_content.return_value = mock_attachments
        
        # Execute
        result = download_page(self.mock_confluence, self.page_id, self.temp_dir)
        
        # Verify
        self.assertIn("Downloaded: Empty Page", result)
        
        # Check empty file creation
        text_file = self.temp_dir / "Empty Page" / "Empty Page.txt"
        self.assertTrue(text_file.exists())
        self.assertEqual(text_file.read_text(encoding='utf-8'), "")


class TestMain(unittest.TestCase):
    """Test the main function."""
    
    @patch.dict(os.environ, {
        'CONFLUENCE_URL': 'https://test.atlassian.net',
        'CONFLUENCE_PAT': 'test_token',
        'CONFLUENCE_SPACE_KEY': 'TEST',
        'MAX_WORKERS': '5'
    })
    @patch('confluence_sync.Confluence')
    @patch('confluence_sync.Path')
    @patch('concurrent.futures.ThreadPoolExecutor')
    def test_main_success(self, mock_executor, mock_path, mock_confluence_class):
        """Test successful main execution."""
        # Mock Confluence instance
        mock_confluence = Mock()
        mock_confluence_class.return_value = mock_confluence
        
        # Mock pages data
        mock_pages = [
            {'id': '1'},
            {'id': '2'},
            {'id': '3'}
        ]
        mock_confluence.get_all_pages_from_space.return_value = mock_pages
        
        # Mock Path
        mock_output_dir = Mock()
        mock_path.return_value = mock_output_dir
        
        # Mock ThreadPoolExecutor
        mock_executor_instance = Mock()
        mock_executor.return_value.__enter__.return_value = mock_executor_instance
        
        # Mock futures
        mock_future1 = Mock()
        mock_future1.result.return_value = "Downloaded: Page 1"
        mock_future2 = Mock()
        mock_future2.result.return_value = "Downloaded: Page 2"
        mock_future3 = Mock()
        mock_future3.result.return_value = "Downloaded: Page 3"
        
        mock_executor_instance.submit.side_effect = [mock_future1, mock_future2, mock_future3]
        
        # Mock as_completed
        with patch('concurrent.futures.as_completed', return_value=[mock_future1, mock_future2, mock_future3]):
            # Execute
            with patch('builtins.print') as mock_print:
                main()
        
        # Verify Confluence initialization
        mock_confluence_class.assert_called_once_with(
            url='https://test.atlassian.net',
            token='test_token'
        )
        
        # Verify space query
        mock_confluence.get_all_pages_from_space.assert_called_once_with('TEST', expand='id')
        
        # Verify executor usage
        self.assertEqual(mock_executor_instance.submit.call_count, 3)
        
        # Verify print statements
        mock_print.assert_any_call("Downloading 3 pages...")
        mock_print.assert_any_call("Done!")
    
    @patch.dict(os.environ, {}, clear=True)
    def test_main_missing_env_vars(self):
        """Test main with missing environment variables."""
        with patch('builtins.print') as mock_print:
            main()
        
        mock_print.assert_called_with("Set CONFLUENCE_URL, CONFLUENCE_PAT, and CONFLUENCE_SPACE_KEY")
    
    @patch.dict(os.environ, {
        'CONFLUENCE_URL': 'https://test.atlassian.net',
        'CONFLUENCE_PAT': '',  # Empty token
        'CONFLUENCE_SPACE_KEY': 'TEST'
    })
    def test_main_empty_token(self):
        """Test main with empty token."""
        with patch('builtins.print') as mock_print:
            main()
        
        mock_print.assert_called_with("Set CONFLUENCE_URL, CONFLUENCE_PAT, and CONFLUENCE_SPACE_KEY")
    
    @patch.dict(os.environ, {
        'CONFLUENCE_URL': 'https://test.atlassian.net',
        'CONFLUENCE_PAT': 'test_token',
        'CONFLUENCE_SPACE_KEY': 'TEST'
        # MAX_WORKERS not set, should default to 10
    })
    @patch('confluence_sync.Confluence')
    @patch('confluence_sync.Path')
    def test_main_default_workers(self, mock_path, mock_confluence_class):
        """Test main with default MAX_WORKERS value."""
        mock_confluence = Mock()
        mock_confluence_class.return_value = mock_confluence
        mock_confluence.get_all_pages_from_space.return_value = []
        
        mock_output_dir = Mock()
        mock_path.return_value = mock_output_dir
        
        with patch('concurrent.futures.ThreadPoolExecutor') as mock_executor:
            with patch('builtins.print'):
                main()
        
        # Verify default max_workers is used (10)
        mock_executor.assert_called_once_with(max_workers=10)


class TestIntegration(unittest.TestCase):
    """Integration tests."""
    
    def test_end_to_end_flow(self):
        """Test the complete flow with mocked Confluence API."""
        with tempfile.TemporaryDirectory() as temp_dir:
            # Setup
            output_dir = Path(temp_dir)
            mock_confluence = Mock()
            
            # Mock data
            mock_page = {
                'title': 'Integration Test Page',
                'body': {
                    'storage': {
                        'value': '<h1>Test</h1><p>Integration test content</p>'
                    }
                }
            }
            
            mock_attachments = {
                'results': [
                    {'id': 'att1', 'title': 'test.txt'}
                ]
            }
            
            mock_confluence.get_page_by_id.return_value = mock_page
            mock_confluence.get_attachments_from_content.return_value = mock_attachments
            mock_confluence.get_attachment_by_id.return_value = b'test attachment content'
            
            # Execute
            result = download_page(mock_confluence, '123', output_dir)
            
            # Verify complete flow
            self.assertIn("Downloaded: Integration Test Page", result)
            
            # Check all expected files exist
            page_dir = output_dir / "Integration Test Page"
            self.assertTrue(page_dir.exists())
            
            text_file = page_dir / "Integration Test Page.txt"
            self.assertTrue(text_file.exists())
            
            att_dir = page_dir / "attachments"
            self.assertTrue(att_dir.exists())
            
            att_file = att_dir / "test.txt"
            self.assertTrue(att_file.exists())
            
            # Verify content
            content = text_file.read_text(encoding='utf-8')
            self.assertIn("Test", content)
            self.assertIn("Integration test content", content)
            
            att_content = att_file.read_bytes()
            self.assertEqual(att_content, b'test attachment content')


if __name__ == '__main__':
    # Create test suite
    test_suite = unittest.TestSuite()
    
    # Add all test classes
    test_classes = [
        TestCleanText,
        TestDownloadPage,
        TestMain,
        TestIntegration
    ]
    
    for test_class in test_classes:
        tests = unittest.TestLoader().loadTestsFromTestCase(test_class)
        test_suite.addTests(tests)
    
    # Run tests with detailed output
    runner = unittest.TextTestRunner(verbosity=2, buffer=True)
    result = runner.run(test_suite)
    
    # Print summary
    print(f"\n{'='*60}")
    print(f"TEST SUMMARY")
    print(f"{'='*60}")
    print(f"Tests run: {result.testsRun}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    print(f"Success rate: {((result.testsRun - len(result.failures) - len(result.errors)) / result.testsRun * 100):.1f}%")
    
    if result.failures:
        print(f"\nFAILURES:")
        for test, traceback in result.failures:
            print(f"- {test}: {traceback.split('AssertionError: ')[-1].split('\\n')[0]}")
    
    if result.errors:
        print(f"\nERRORS:")
        for test, traceback in result.errors:
            print(f"- {test}: {traceback.split('\\n')[-2]}")
    
    # Exit with appropriate code
    exit_code = 0 if result.wasSuccessful() else 1
    print(f"\nExiting with code: {exit_code}")
    exit(exit_code)