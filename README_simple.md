# Lean Confluence Downloader

Simple script to download Confluence content for LLM embedding.

## Setup

```bash
pip install -r requirements.txt
```

## Usage

```bash
export CONFLUENCE_URL="https://your-domain.atlassian.net"
export CONFLUENCE_PAT="your_token"
export CONFLUENCE_SPACE_KEY="DOCS"
export MAX_WORKERS="10"

python confluence_sync.py
```

## Output

Creates `confluence_backup/` with:
- `PageTitle/PageTitle.txt` - clean text for embedding
- `PageTitle/attachments/` - any attachments

Done. 50 lines vs 500+.