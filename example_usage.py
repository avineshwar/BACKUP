#!/usr/bin/env python3
"""
Example usage scenarios for the Enhanced Confluence Content Downloader.

This file demonstrates various ways to use the downloader for different
use cases and requirements.
"""

import os
from confluence_downloader import Config, ConfluenceDownloader

def example_basic_download():
    """Example 1: Basic download with minimal configuration."""
    print("Example 1: Basic Download")
    print("-" * 30)
    
    config = Config(
        confluence_url="https://mycompany.atlassian.net/wiki",
        pat=os.environ.get("CONFLUENCE_PAT"),
        space_key="DOCS",
        output_folder="./basic_backup"
    )
    
    with ConfluenceDownloader(config) as downloader:
        downloader.download_all_content()

def example_large_space_download():
    """Example 2: Optimized download for large spaces."""
    print("Example 2: Large Space Download")
    print("-" * 35)
    
    config = Config(
        confluence_url=os.environ.get("CONFLUENCE_URL"),
        pat=os.environ.get("CONFLUENCE_PAT"),
        space_key=os.environ.get("CONFLUENCE_SPACE_KEY"),
        output_folder="./large_space_backup",
        max_workers=15,           # More threads for faster download
        rate_limit_delay=0.05,    # Shorter delay between requests
        timeout=120,              # Longer timeout for large files
        max_retries=5,            # More retries for stability
        preserve_hierarchy=True,  # Keep folder structure
        save_metadata=True        # Save comprehensive metadata
    )
    
    with ConfluenceDownloader(config) as downloader:
        downloader.download_all_content()

def example_conservative_download():
    """Example 3: Conservative download for rate-limited environments."""
    print("Example 3: Conservative Download")
    print("-" * 36)
    
    config = Config(
        confluence_url=os.environ.get("CONFLUENCE_URL"),
        pat=os.environ.get("CONFLUENCE_PAT"),
        space_key=os.environ.get("CONFLUENCE_SPACE_KEY"),
        output_folder="./conservative_backup",
        max_workers=3,            # Fewer threads to avoid rate limiting
        rate_limit_delay=1.0,     # Longer delay between requests
        retry_delay=3.0,          # Longer delay between retries
        timeout=60,               # Standard timeout
        max_retries=3,            # Conservative retry count
        preserve_hierarchy=False, # Flat structure for simplicity
        save_metadata=False       # Skip metadata to save space
    )
    
    with ConfluenceDownloader(config) as downloader:
        downloader.download_all_content()

def example_resumable_download():
    """Example 4: Resumable download that skips existing files."""
    print("Example 4: Resumable Download")
    print("-" * 34)
    
    config = Config(
        confluence_url=os.environ.get("CONFLUENCE_URL"),
        pat=os.environ.get("CONFLUENCE_PAT"),
        space_key=os.environ.get("CONFLUENCE_SPACE_KEY"),
        output_folder="./resumable_backup",
        skip_existing=True,       # Skip files that already exist
        max_workers=8,
        preserve_hierarchy=True,
        save_metadata=True
    )
    
    print("This download will skip any files that already exist.")
    print("You can interrupt and restart it without losing progress.")
    
    with ConfluenceDownloader(config) as downloader:
        downloader.download_all_content()

def example_text_only_download():
    """Example 5: Text-only download optimized for LLM embedding."""
    print("Example 5: Text-Only Download for LLM")
    print("-" * 42)
    
    config = Config(
        confluence_url=os.environ.get("CONFLUENCE_URL"),
        pat=os.environ.get("CONFLUENCE_PAT"),
        space_key=os.environ.get("CONFLUENCE_SPACE_KEY"),
        output_folder="./text_only_backup",
        max_workers=12,
        preserve_hierarchy=True,  # Organize by page hierarchy
        save_metadata=True,       # Keep metadata for reference
        skip_existing=True        # Resumable downloads
    )
    
    print("This example downloads content optimized for LLM text embedding.")
    print("Each page will be saved as clean plain text suitable for vector databases.")
    
    with ConfluenceDownloader(config) as downloader:
        downloader.download_all_content()

def main():
    """Run example based on user choice."""
    print("Enhanced Confluence Content Downloader - Examples")
    print("=" * 55)
    print()
    
    examples = [
        ("Basic Download", example_basic_download),
        ("Large Space Download", example_large_space_download),
        ("Conservative Download", example_conservative_download),
        ("Resumable Download", example_resumable_download),
        ("Text-Only for LLM", example_text_only_download)
    ]
    
    print("Available examples:")
    for i, (name, _) in enumerate(examples, 1):
        print(f"{i}. {name}")
    
    print()
    
    try:
        choice = int(input("Select an example (1-5): ")) - 1
        if 0 <= choice < len(examples):
            name, func = examples[choice]
            print()
            func()
        else:
            print("Invalid choice. Please select 1-5.")
    except ValueError:
        print("Invalid input. Please enter a number.")
    except KeyboardInterrupt:
        print("\nExample interrupted by user.")

if __name__ == "__main__":
    main()