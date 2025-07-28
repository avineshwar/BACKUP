#!/usr/bin/env python3
"""
Lean Confluence Content Downloader for LLM Text Embedding

Simple script using atlassian-python-api library.
"""

import os
import concurrent.futures
from pathlib import Path
from atlassian import Confluence
from bs4 import BeautifulSoup
import re

def clean_text(html_content):
    """Extract clean text from HTML for LLM embedding."""
    if not html_content:
        return ""
    
    soup = BeautifulSoup(html_content, 'html.parser')
    text = soup.get_text(separator='\n', strip=True)
    return re.sub(r'\n\s*\n\s*\n', '\n\n', text).strip()

def download_page(confluence, page_id, output_dir):
    """Download a single page and its attachments."""
    try:
        # Get page content
        page = confluence.get_page_by_id(page_id, expand='body.storage,space,ancestors')
        title = re.sub(r'[<>:"/\\|?*]', '_', page['title'])
        
        # Create page directory
        page_dir = output_dir / title
        page_dir.mkdir(exist_ok=True)
        
        # Save cleaned text
        content = page.get('body', {}).get('storage', {}).get('value', '')
        text = clean_text(content)
        (page_dir / f"{title}.txt").write_text(text, encoding='utf-8')
        
        # Download attachments
        attachments = confluence.get_attachments_from_content(page_id)['results']
        if attachments:
            att_dir = page_dir / 'attachments'
            att_dir.mkdir(exist_ok=True)
            
            for att in attachments:
                att_data = confluence.get_attachment_by_id(att['id'])
                filename = re.sub(r'[<>:"/\\|?*]', '_', att['title'])
                (att_dir / filename).write_bytes(att_data)
        
        return f"Downloaded: {title}"
    except Exception as e:
        return f"Error: {page_id} - {e}"

def main():
    """Main function."""
    # Configuration from environment
    url = os.environ.get('CONFLUENCE_URL', 'https://your-domain.atlassian.net')
    token = os.environ.get('CONFLUENCE_PAT', '')
    space_key = os.environ.get('CONFLUENCE_SPACE_KEY', '')
    max_workers = int(os.environ.get('MAX_WORKERS', '10'))
    
    if not all([url, token, space_key]):
        print("Set CONFLUENCE_URL, CONFLUENCE_PAT, and CONFLUENCE_SPACE_KEY")
        return
    
    # Initialize
    confluence = Confluence(url=url, token=token)
    output_dir = Path('./confluence_backup')
    output_dir.mkdir(exist_ok=True)
    
    # Get all pages
    pages = confluence.get_all_pages_from_space(space_key, expand='id')
    page_ids = [p['id'] for p in pages]
    
    print(f"Downloading {len(page_ids)} pages...")
    
    # Download with threading
    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = [executor.submit(download_page, confluence, pid, output_dir) for pid in page_ids]
        
        for i, future in enumerate(concurrent.futures.as_completed(futures), 1):
            print(f"[{i}/{len(page_ids)}] {future.result()}")
    
    print("Done!")

if __name__ == "__main__":
    main()