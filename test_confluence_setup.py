#!/usr/bin/env python3
"""
Test script to verify Confluence API connection and setup.

This script performs basic validation of your Confluence configuration
without downloading any content.
"""

import requests
import os
import sys
from confluence_downloader import Config

def test_confluence_connection(config: Config) -> bool:
    """Test basic connectivity to Confluence API."""
    print("Testing Confluence API connection...")
    
    headers = {
        "Authorization": f"Bearer {config.pat}",
        "Accept": "application/json",
        "User-Agent": "ConfluenceDownloader-Test/1.0"
    }
    
    # Test basic API access
    try:
        url = f"{config.confluence_url}/rest/api/content"
        response = requests.get(url, headers=headers, timeout=10)
        
        if response.status_code == 200:
            print("✅ Successfully connected to Confluence API")
            return True
        elif response.status_code == 401:
            print("❌ Authentication failed - check your PAT token")
            return False
        elif response.status_code == 403:
            print("❌ Access forbidden - check your permissions")
            return False
        else:
            print(f"❌ API request failed with status code: {response.status_code}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Connection error: {e}")
        return False

def test_space_access(config: Config) -> bool:
    """Test access to the specified space."""
    print(f"Testing access to space: {config.space_key}")
    
    headers = {
        "Authorization": f"Bearer {config.pat}",
        "Accept": "application/json",
        "User-Agent": "ConfluenceDownloader-Test/1.0"
    }
    
    try:
        # Try to fetch space information
        url = f"{config.confluence_url}/rest/api/space/{config.space_key}"
        response = requests.get(url, headers=headers, timeout=10)
        
        if response.status_code == 200:
            space_data = response.json()
            print(f"✅ Space found: {space_data.get('name', 'Unknown')}")
            
            # Test fetching pages from the space
            url = f"{config.confluence_url}/rest/api/content?spaceKey={config.space_key}&type=page&limit=1"
            response = requests.get(url, headers=headers, timeout=10)
            
            if response.status_code == 200:
                pages_data = response.json()
                total_pages = pages_data.get('size', 0)
                print(f"✅ Found {total_pages} pages in space")
                return True
            else:
                print(f"❌ Could not fetch pages from space (status: {response.status_code})")
                return False
                
        elif response.status_code == 404:
            print(f"❌ Space '{config.space_key}' not found")
            return False
        elif response.status_code == 403:
            print(f"❌ No access to space '{config.space_key}'")
            return False
        else:
            print(f"❌ Space access test failed with status code: {response.status_code}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Connection error: {e}")
        return False

def test_output_directory(config: Config) -> bool:
    """Test write access to output directory."""
    print(f"Testing output directory: {config.output_folder}")
    
    try:
        os.makedirs(config.output_folder, exist_ok=True)
        
        # Test write permissions
        test_file = os.path.join(config.output_folder, "test_write.tmp")
        with open(test_file, 'w') as f:
            f.write("test")
        
        # Clean up
        os.remove(test_file)
        
        print("✅ Output directory is writable")
        return True
        
    except Exception as e:
        print(f"❌ Cannot write to output directory: {e}")
        return False

def main():
    """Main test function."""
    print("Confluence Downloader Setup Test")
    print("=" * 40)
    
    # Load configuration
    config = Config(
        confluence_url=os.environ.get("CONFLUENCE_URL", ""),
        pat=os.environ.get("CONFLUENCE_PAT", ""),
        space_key=os.environ.get("CONFLUENCE_SPACE_KEY", ""),
        output_folder=os.environ.get("OUTPUT_FOLDER", "./confluence_backup"),
    )
    
    # Validate configuration
    print("Validating configuration...")
    
    if not config.confluence_url:
        print("❌ CONFLUENCE_URL not set")
        return False
    else:
        print(f"✅ Confluence URL: {config.confluence_url}")
    
    if not config.pat:
        print("❌ CONFLUENCE_PAT not set")
        return False
    else:
        print("✅ PAT token configured")
    
    if not config.space_key:
        print("❌ CONFLUENCE_SPACE_KEY not set")
        return False
    else:
        print(f"✅ Space key: {config.space_key}")
    
    print()
    
    # Run tests
    tests = [
        ("API Connection", lambda: test_confluence_connection(config)),
        ("Space Access", lambda: test_space_access(config)),
        ("Output Directory", lambda: test_output_directory(config)),
    ]
    
    all_passed = True
    for test_name, test_func in tests:
        print(f"Running {test_name} test...")
        if not test_func():
            all_passed = False
        print()
    
    # Summary
    if all_passed:
        print("🎉 All tests passed! Your setup is ready.")
        print(f"You can now run: python confluence_downloader.py")
        return True
    else:
        print("❌ Some tests failed. Please fix the issues above.")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)