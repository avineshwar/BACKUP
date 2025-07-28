#!/usr/bin/env python3
"""
Enhanced Confluence Content Downloader for LLM Text Embedding

This script downloads all pages and attachments from a specified Confluence space
using multithreading for optimal performance. The content is processed and saved
in a format optimized for LLM text embedding.

Features:
- Multithreaded downloads for faster performance
- Robust error handling and retry mechanisms
- Progress tracking and detailed logging
- Content cleaning optimized for LLM embedding
- Hierarchical folder structure preservation
- Rate limiting to avoid API throttling
- Resumable downloads (skip already downloaded content)
- Comprehensive metadata preservation

Author: AI Assistant
Version: 2.0
"""

import requests
import os
import json
import time
import logging
from concurrent.futures import ThreadPoolExecutor, as_completed
from bs4 import BeautifulSoup
from urllib.parse import urlparse, unquote
from pathlib import Path
from datetime import datetime
import re
import threading
from dataclasses import dataclass
from typing import List, Dict, Optional, Tuple
import hashlib


# --- Configuration ---
@dataclass
class Config:
    """Configuration class for the Confluence downloader."""
    confluence_url: str = "https://your-domain.atlassian.net/wiki"
    pat: str = ""
    space_key: str = "YOUR_SPACE_KEY"
    output_folder: str = "Confluence_Backup"
    max_workers: int = 10
    max_retries: int = 3
    retry_delay: float = 1.0
    rate_limit_delay: float = 0.1
    chunk_size: int = 8192
    page_limit: int = 50
    timeout: int = 30
    skip_existing: bool = True
    save_metadata: bool = True
    preserve_hierarchy: bool = True


class ConfluenceDownloader:
    """Enhanced Confluence content downloader with multithreading support."""
    
    def __init__(self, config: Config):
        self.config = config
        self.session = requests.Session()
        self.session.headers.update({
            "Authorization": f"Bearer {config.pat}",
            "Accept": "application/json",
            "User-Agent": "ConfluenceDownloader/2.0"
        })
        
        # Thread-safe counters
        self._lock = threading.Lock()
        self.stats = {
            'pages_downloaded': 0,
            'pages_skipped': 0,
            'attachments_downloaded': 0,
            'errors': 0,
            'total_size': 0
        }
        
        # Setup logging
        self._setup_logging()
        
        # Create output directory
        Path(self.config.output_folder).mkdir(parents=True, exist_ok=True)
    
    def _setup_logging(self):
        """Setup comprehensive logging."""
        log_format = '%(asctime)s - %(levelname)s - %(message)s'
        logging.basicConfig(
            level=logging.INFO,
            format=log_format,
            handlers=[
                logging.FileHandler(
                    Path(self.config.output_folder) / 'download.log'
                ),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def _sanitize_filename(self, filename: str) -> str:
        """Sanitize filename for filesystem compatibility."""
        # Remove/replace invalid characters
        filename = re.sub(r'[<>:"/\\|?*]', '_', filename)
        # Limit length
        if len(filename) > 200:
            filename = filename[:200]
        return filename.strip()
    
    def _make_request(self, url: str, **kwargs) -> Optional[requests.Response]:
        """Make HTTP request with retry logic and rate limiting."""
        for attempt in range(self.config.max_retries):
            try:
                # Rate limiting
                time.sleep(self.config.rate_limit_delay)
                
                response = self.session.get(
                    url, 
                    timeout=self.config.timeout,
                    **kwargs
                )
                response.raise_for_status()
                return response
                
            except requests.exceptions.RequestException as e:
                self.logger.warning(
                    f"Request failed (attempt {attempt + 1}/{self.config.max_retries}): {e}"
                )
                if attempt < self.config.max_retries - 1:
                    time.sleep(self.config.retry_delay * (2 ** attempt))
                else:
                    self.logger.error(f"Request failed after {self.config.max_retries} attempts: {url}")
                    with self._lock:
                        self.stats['errors'] += 1
        return None
    
    def fetch_all_pages_in_space(self) -> List[Dict]:
        """Fetch metadata for all pages in the space with pagination."""
        self.logger.info(f"Fetching pages from space: {self.config.space_key}")
        pages = []
        start = 0
        
        while True:
            url = (f"{self.config.confluence_url}/rest/api/content"
                   f"?spaceKey={self.config.space_key}&type=page"
                   f"&start={start}&limit={self.config.page_limit}"
                   f"&expand=ancestors,space,version")
            
            response = self._make_request(url)
            if not response:
                break
                
            data = response.json()
            batch_pages = data.get('results', [])
            pages.extend(batch_pages)
            
            if len(batch_pages) < self.config.page_limit:
                break
            start += self.config.page_limit
            
            self.logger.info(f"Fetched {len(pages)} pages so far...")
        
        self.logger.info(f"Found {len(pages)} total pages in space '{self.config.space_key}'")
        return pages
    
    def _get_page_hierarchy_path(self, page: Dict) -> str:
        """Build hierarchical path for the page based on its ancestors."""
        if not self.config.preserve_hierarchy:
            return self._sanitize_filename(page['title'])
        
        path_parts = []
        
        # Add ancestors to path
        for ancestor in page.get('ancestors', []):
            path_parts.append(self._sanitize_filename(ancestor['title']))
        
        # Add current page
        path_parts.append(self._sanitize_filename(page['title']))
        
        return os.path.join(*path_parts)
    
    def _clean_content_for_embedding(self, html_content: str) -> str:
        """Clean HTML content to extract plain text optimized for LLM embedding."""
        if not html_content:
            return ""
        
        # Parse HTML
        soup = BeautifulSoup(html_content, 'html.parser')
        
        # Remove script and style elements
        for script in soup(["script", "style"]):
            script.decompose()
        
        # Remove Confluence-specific macros that don't add text value
        for macro in soup.find_all(['ac:structured-macro']):
            macro_name = macro.get('ac:name', '')
            if macro_name in ['info', 'note', 'warning', 'tip']:
                # Keep content of these macros
                continue
            elif macro_name in ['toc', 'children', 'recently-updated']:
                # Remove these macros entirely
                macro.decompose()
        
        # Extract text with proper spacing
        text = soup.get_text(separator='\n', strip=True)
        
        # Clean up excessive whitespace
        text = re.sub(r'\n\s*\n\s*\n', '\n\n', text)
        text = re.sub(r'[ \t]+', ' ', text)
        
        return text.strip()
    
    def _save_page_metadata(self, page: Dict, page_folder: Path):
        """Save page metadata as JSON for reference."""
        if not self.config.save_metadata:
            return
        
        metadata = {
            'id': page['id'],
            'title': page['title'],
            'type': page['type'],
            'space_key': page['space']['key'],
            'space_name': page['space']['name'],
            'version': page.get('version', {}),
            'created_date': page.get('history', {}).get('createdDate'),
            'last_modified': page.get('version', {}).get('when'),
            'url': f"{self.config.confluence_url}/spaces/{page['space']['key']}/pages/{page['id']}",
            'ancestors': [{'id': a['id'], 'title': a['title']} for a in page.get('ancestors', [])]
        }
        
        metadata_file = page_folder / 'metadata.json'
        with open(metadata_file, 'w', encoding='utf-8') as f:
            json.dump(metadata, f, indent=2, ensure_ascii=False)
    
    def download_attachments(self, page_id: str, page_folder: Path) -> int:
        """Download all attachments for a given page."""
        attachments_url = f"{self.config.confluence_url}/rest/api/content/{page_id}/child/attachment"
        
        response = self._make_request(attachments_url)
        if not response:
            return 0
        
        attachments = response.json().get('results', [])
        downloaded_count = 0
        
        if attachments:
            attachments_folder = page_folder / 'attachments'
            attachments_folder.mkdir(exist_ok=True)
        
        for attachment in attachments:
            try:
                filename = self._sanitize_filename(attachment['title'])
                local_path = attachments_folder / filename
                
                # Skip if already exists
                if self.config.skip_existing and local_path.exists():
                    self.logger.debug(f"Skipping existing attachment: {filename}")
                    continue
                
                download_link = self.config.confluence_url + attachment['_links']['download']
                
                file_response = self._make_request(download_link, stream=True)
                if not file_response:
                    continue
                
                with open(local_path, 'wb') as f:
                    for chunk in file_response.iter_content(chunk_size=self.config.chunk_size):
                        f.write(chunk)
                
                downloaded_count += 1
                file_size = local_path.stat().st_size
                
                with self._lock:
                    self.stats['attachments_downloaded'] += 1
                    self.stats['total_size'] += file_size
                
                self.logger.debug(f"Downloaded attachment: {filename} ({file_size} bytes)")
                
            except Exception as e:
                self.logger.error(f"Error downloading attachment {attachment.get('title', 'unknown')}: {e}")
                with self._lock:
                    self.stats['errors'] += 1
        
        return downloaded_count
    
    def download_page_content(self, page: Dict) -> Tuple[bool, str]:
        """Download and process a single page's content."""
        page_id = page['id']
        page_title = page['title']
        
        try:
            # Create hierarchical folder structure
            relative_path = self._get_page_hierarchy_path(page)
            page_folder = Path(self.config.output_folder) / relative_path
            
            # Check if page already exists
            text_file_path = page_folder / f"{self._sanitize_filename(page_title)}.txt"
            if self.config.skip_existing and text_file_path.exists():
                with self._lock:
                    self.stats['pages_skipped'] += 1
                return True, f"Skipped existing page: {page_title}"
            
            page_folder.mkdir(parents=True, exist_ok=True)
            
            # Fetch page content in storage format
            content_url = f"{self.config.confluence_url}/rest/api/content/{page_id}?expand=body.storage"
            
            response = self._make_request(content_url)
            if not response:
                return False, f"Failed to fetch content for page: {page_title}"
            
            content_json = response.json()
            storage_value = content_json.get('body', {}).get('storage', {}).get('value', '')
            
            # Clean HTML content for LLM embedding
            plain_text = self._clean_content_for_embedding(storage_value)
            
            # Save cleaned text
            with open(text_file_path, 'w', encoding='utf-8') as f:
                f.write(plain_text)
            
            # Save page metadata
            self._save_page_metadata(page, page_folder)
            
            # Download attachments
            num_attachments = self.download_attachments(page_id, page_folder)
            
            # Update statistics
            text_size = len(plain_text.encode('utf-8'))
            with self._lock:
                self.stats['pages_downloaded'] += 1
                self.stats['total_size'] += text_size
            
            return True, f"Downloaded page: {page_title} ({num_attachments} attachments)"
            
        except Exception as e:
            self.logger.error(f"Error processing page '{page_title}': {e}")
            with self._lock:
                self.stats['errors'] += 1
            return False, f"Error processing page '{page_title}': {e}"
    
    def download_all_content(self):
        """Main method to download all content using multithreading."""
        start_time = datetime.now()
        self.logger.info("Starting Confluence content download...")
        
        # Fetch all pages
        all_pages = self.fetch_all_pages_in_space()
        if not all_pages:
            self.logger.error("No pages found or error in fetching pages. Exiting.")
            return
        
        # Download pages using thread pool
        self.logger.info(f"Starting download of {len(all_pages)} pages using {self.config.max_workers} workers...")
        
        with ThreadPoolExecutor(max_workers=self.config.max_workers) as executor:
            # Submit all download tasks
            futures = {
                executor.submit(self.download_page_content, page): page 
                for page in all_pages
            }
            
            # Process completed tasks
            completed = 0
            for future in as_completed(futures):
                page = futures[future]
                completed += 1
                
                try:
                    success, message = future.result()
                    if success:
                        self.logger.info(f"[{completed}/{len(all_pages)}] {message}")
                    else:
                        self.logger.error(f"[{completed}/{len(all_pages)}] {message}")
                        
                except Exception as e:
                    self.logger.error(f"Task for page '{page.get('title', 'unknown')}' generated an exception: {e}")
                    with self._lock:
                        self.stats['errors'] += 1
                
                # Progress update every 10 pages
                if completed % 10 == 0:
                    self._log_progress(completed, len(all_pages))
        
        # Final statistics
        end_time = datetime.now()
        duration = end_time - start_time
        self._log_final_stats(duration)
    
    def _log_progress(self, completed: int, total: int):
        """Log progress statistics."""
        with self._lock:
            progress = (completed / total) * 100
            self.logger.info(
                f"Progress: {progress:.1f}% ({completed}/{total}) - "
                f"Pages: {self.stats['pages_downloaded']} downloaded, {self.stats['pages_skipped']} skipped - "
                f"Attachments: {self.stats['attachments_downloaded']} - "
                f"Errors: {self.stats['errors']}"
            )
    
    def _log_final_stats(self, duration):
        """Log final download statistics."""
        total_size_mb = self.stats['total_size'] / (1024 * 1024)
        
        self.logger.info("=" * 60)
        self.logger.info("DOWNLOAD COMPLETE")
        self.logger.info("=" * 60)
        self.logger.info(f"Duration: {duration}")
        self.logger.info(f"Pages downloaded: {self.stats['pages_downloaded']}")
        self.logger.info(f"Pages skipped: {self.stats['pages_skipped']}")
        self.logger.info(f"Attachments downloaded: {self.stats['attachments_downloaded']}")
        self.logger.info(f"Total data downloaded: {total_size_mb:.2f} MB")
        self.logger.info(f"Errors encountered: {self.stats['errors']}")
        self.logger.info(f"Output folder: {self.config.output_folder}")
        
        # Save final statistics
        stats_file = Path(self.config.output_folder) / 'download_stats.json'
        with open(stats_file, 'w') as f:
            json.dump({
                **self.stats,
                'duration_seconds': duration.total_seconds(),
                'completion_time': datetime.now().isoformat(),
                'config': {
                    'space_key': self.config.space_key,
                    'max_workers': self.config.max_workers,
                    'preserve_hierarchy': self.config.preserve_hierarchy
                }
            }, f, indent=2)
    
    def __enter__(self):
        """Context manager entry."""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit - cleanup resources."""
        self.session.close()


def main():
    """Main function to run the Confluence downloader."""
    # Load configuration from environment variables or use defaults
    config = Config(
        confluence_url=os.environ.get("CONFLUENCE_URL", "https://your-domain.atlassian.net/wiki"),
        pat=os.environ.get("CONFLUENCE_PAT", ""),
        space_key=os.environ.get("CONFLUENCE_SPACE_KEY", "YOUR_SPACE_KEY"),
        output_folder=os.environ.get("OUTPUT_FOLDER", "Confluence_Backup"),
        max_workers=int(os.environ.get("MAX_WORKERS", "10")),
        skip_existing=os.environ.get("SKIP_EXISTING", "true").lower() == "true"
    )
    
    # Validation
    if not config.pat or config.pat == "":
        print("Error: Please set your Personal Access Token (PAT) as environment variable CONFLUENCE_PAT")
        print("or modify the config in the script.")
        return 1
    
    if config.space_key == "YOUR_SPACE_KEY":
        print("Error: Please set your Confluence space key as environment variable CONFLUENCE_SPACE_KEY")
        print("or modify the config in the script.")
        return 1
    
    # Run downloader
    try:
        with ConfluenceDownloader(config) as downloader:
            downloader.download_all_content()
        return 0
    except KeyboardInterrupt:
        print("\nDownload interrupted by user.")
        return 1
    except Exception as e:
        print(f"Unexpected error: {e}")
        return 1


if __name__ == "__main__":
    exit(main())