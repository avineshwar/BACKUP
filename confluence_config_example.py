#!/usr/bin/env python3
"""
Example configuration file for the Confluence Content Downloader

Copy this file and modify the values according to your needs.
You can also set these values as environment variables.
"""

import os
from confluence_downloader import Config, ConfluenceDownloader

# Example 1: Basic configuration
def basic_config():
    return Config(
        confluence_url="https://mycompany.atlassian.net/wiki",
        pat="ATATT3xFfGF0...",  # Your Personal Access Token
        space_key="DOCS",       # Space key to download
        output_folder="./confluence_backup",
        max_workers=8,          # Adjust based on your system and API limits
        skip_existing=True,     # Skip already downloaded content for resumability
    )

# Example 2: High-performance configuration for large spaces
def high_performance_config():
    return Config(
        confluence_url="https://mycompany.atlassian.net/wiki",
        pat=os.environ.get("CONFLUENCE_PAT"),  # More secure - use env variable
        space_key=os.environ.get("CONFLUENCE_SPACE_KEY"),
        output_folder="./large_space_backup",
        max_workers=15,         # More threads for faster download
        max_retries=5,          # More retries for unstable connections
        retry_delay=0.5,        # Shorter retry delay
        rate_limit_delay=0.05,  # Shorter rate limit delay (be careful!)
        timeout=60,             # Longer timeout for large files
        preserve_hierarchy=True, # Maintain folder structure
        save_metadata=True,     # Save detailed metadata
    )

# Example 3: Conservative configuration for limited API access
def conservative_config():
    return Config(
        confluence_url="https://mycompany.atlassian.net/wiki",
        pat=os.environ.get("CONFLUENCE_PAT"),
        space_key=os.environ.get("CONFLUENCE_SPACE_KEY"),
        output_folder="./confluence_conservative",
        max_workers=3,          # Fewer threads to avoid rate limiting
        max_retries=3,
        retry_delay=2.0,        # Longer delays between retries
        rate_limit_delay=0.5,   # Longer rate limit delay
        timeout=30,
        preserve_hierarchy=False, # Flat structure for simplicity
        save_metadata=False,    # Skip metadata to save space
    )

# Example usage
if __name__ == "__main__":
    # Choose your configuration
    config = basic_config()  # or high_performance_config() or conservative_config()
    
    # Run the downloader
    with ConfluenceDownloader(config) as downloader:
        downloader.download_all_content()