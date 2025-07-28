# Enhanced Confluence Content Downloader

A high-performance, multithreaded Python script for downloading entire Confluence spaces, optimized for LLM text embedding and knowledge base creation.

## Features

- 🚀 **Multithreaded Downloads**: Concurrent downloads for maximum speed
- 🔄 **Resumable Downloads**: Skip already downloaded content
- 📊 **Progress Tracking**: Real-time progress updates and statistics
- 🧹 **Content Cleaning**: Text extraction optimized for LLM embedding
- 📁 **Hierarchical Structure**: Preserves page hierarchy and organization
- 🔄 **Retry Logic**: Robust error handling with automatic retries
- 📝 **Comprehensive Logging**: Detailed logging to file and console
- 🔒 **Secure Authentication**: Support for Personal Access Tokens (PAT)
- 📎 **Attachment Support**: Downloads all page attachments
- 📊 **Metadata Preservation**: Saves page metadata for reference

## Installation

1. Install Python dependencies:
```bash
pip install -r requirements.txt
```

2. Set up your Confluence Personal Access Token (PAT):
   - Go to your Atlassian account settings
   - Navigate to Security > Create and manage API tokens
   - Create a new token and copy it

## Quick Start

### Method 1: Environment Variables (Recommended)

```bash
# Set your configuration
export CONFLUENCE_URL="https://your-domain.atlassian.net/wiki"
export CONFLUENCE_PAT="your_personal_access_token_here"
export CONFLUENCE_SPACE_KEY="YOUR_SPACE_KEY"
export OUTPUT_FOLDER="./confluence_backup"
export MAX_WORKERS="10"

# Run the downloader
python confluence_downloader.py
```

### Method 2: Direct Script Execution

```python
from confluence_downloader import Config, ConfluenceDownloader

config = Config(
    confluence_url="https://your-domain.atlassian.net/wiki",
    pat="your_personal_access_token_here",
    space_key="YOUR_SPACE_KEY",
    output_folder="./confluence_backup",
    max_workers=10
)

with ConfluenceDownloader(config) as downloader:
    downloader.download_all_content()
```

## Configuration Options

| Parameter | Description | Default | Environment Variable |
|-----------|-------------|---------|---------------------|
| `confluence_url` | Your Confluence instance URL | - | `CONFLUENCE_URL` |
| `pat` | Personal Access Token | - | `CONFLUENCE_PAT` |
| `space_key` | Space key to download | - | `CONFLUENCE_SPACE_KEY` |
| `output_folder` | Local output directory | `Confluence_Backup` | `OUTPUT_FOLDER` |
| `max_workers` | Number of download threads | `10` | `MAX_WORKERS` |
| `max_retries` | Maximum retry attempts | `3` | - |
| `retry_delay` | Delay between retries (seconds) | `1.0` | - |
| `rate_limit_delay` | Delay between requests (seconds) | `0.1` | - |
| `timeout` | Request timeout (seconds) | `30` | - |
| `skip_existing` | Skip already downloaded files | `True` | `SKIP_EXISTING` |
| `save_metadata` | Save page metadata as JSON | `True` | - |
| `preserve_hierarchy` | Maintain folder hierarchy | `True` | - |

## Output Structure

The downloader creates the following structure:

```
confluence_backup/
├── download.log                    # Detailed download log
├── download_stats.json            # Final statistics
├── Page_Title_1/
│   ├── Page_Title_1.txt           # Clean text for LLM embedding
│   ├── metadata.json              # Page metadata
│   └── attachments/               # Page attachments
│       ├── image1.png
│       └── document.pdf
├── Parent_Page/
│   └── Child_Page/
│       ├── Child_Page.txt
│       └── metadata.json
└── ...
```

## Content Format for LLM Embedding

The script extracts and cleans content specifically for LLM text embedding:

- **HTML Parsing**: Converts Confluence storage format to clean text
- **Macro Filtering**: Removes non-textual macros (TOC, navigation, etc.)
- **Text Cleaning**: Removes excessive whitespace and formatting
- **UTF-8 Encoding**: Ensures proper character encoding
- **Plain Text Output**: Ready for embedding pipelines

## Performance Tuning

### For Large Spaces (1000+ pages):
```python
config = Config(
    max_workers=15,        # More threads
    rate_limit_delay=0.05, # Faster requests (monitor for 429 errors)
    timeout=60,            # Longer timeout for large files
    max_retries=5          # More retries for stability
)
```

### For Rate-Limited Environments:
```python
config = Config(
    max_workers=3,         # Fewer threads
    rate_limit_delay=0.5,  # Slower requests
    retry_delay=2.0,       # Longer retry delays
    max_retries=3          # Conservative retries
)
```

## Monitoring Progress

The script provides real-time progress updates:

```
2024-01-15 10:30:15 - INFO - Fetching pages from space: DOCS
2024-01-15 10:30:16 - INFO - Found 245 total pages in space 'DOCS'
2024-01-15 10:30:16 - INFO - Starting download of 245 pages using 10 workers...
2024-01-15 10:30:25 - INFO - Progress: 4.1% (10/245) - Pages: 8 downloaded, 2 skipped - Attachments: 15 - Errors: 0
...
2024-01-15 10:35:30 - INFO - ============================================================
2024-01-15 10:35:30 - INFO - DOWNLOAD COMPLETE
2024-01-15 10:35:30 - INFO - ============================================================
2024-01-15 10:35:30 - INFO - Duration: 0:05:15
2024-01-15 10:35:30 - INFO - Pages downloaded: 243
2024-01-15 10:35:30 - INFO - Pages skipped: 2
2024-01-15 10:35:30 - INFO - Attachments downloaded: 156
2024-01-15 10:35:30 - INFO - Total data downloaded: 245.67 MB
2024-01-15 10:35:30 - INFO - Errors encountered: 0
```

## Error Handling

The script includes comprehensive error handling:

- **Network Errors**: Automatic retries with exponential backoff
- **Rate Limiting**: Built-in delays to avoid API throttling
- **File System Errors**: Graceful handling of permission issues
- **Authentication Errors**: Clear error messages for token issues
- **Partial Failures**: Continue downloading other content on individual failures

## Security Best Practices

1. **Use Environment Variables**: Never hardcode PAT tokens in scripts
2. **Token Rotation**: Regularly rotate your Personal Access Tokens
3. **Limited Scope**: Use tokens with minimal required permissions
4. **Secure Storage**: Store tokens securely and never commit to version control

## Troubleshooting

### Common Issues:

**401 Unauthorized**:
- Check your PAT token is valid
- Ensure the token has access to the specified space
- Verify the Confluence URL is correct

**429 Rate Limited**:
- Reduce `max_workers` (try 3-5)
- Increase `rate_limit_delay` (try 0.5-1.0)
- Consider using a more conservative configuration

**Network Timeouts**:
- Increase `timeout` value
- Check your internet connection
- Verify Confluence instance is accessible

**File Permission Errors**:
- Ensure write permissions to output directory
- Check available disk space
- Verify filename character restrictions

## Integration with LLM Pipelines

The output text files are optimized for direct use with:

- **Embeddings Models**: OpenAI, Sentence Transformers, etc.
- **Vector Databases**: Pinecone, Weaviate, ChromaDB, etc.
- **RAG Systems**: LangChain, LlamaIndex, etc.

Example integration:
```python
import os
from pathlib import Path

# Process downloaded content
backup_dir = Path("./confluence_backup")
for txt_file in backup_dir.rglob("*.txt"):
    with open(txt_file, 'r', encoding='utf-8') as f:
        content = f.read()
        # Send to your embedding pipeline
        embeddings = your_embedding_model.encode(content)
        # Store in vector database
        vector_db.store(embeddings, metadata={"source": str(txt_file)})
```

## License

This script is provided as-is for educational and internal use purposes. Please ensure compliance with your organization's Confluence usage policies and Atlassian's API terms of service.