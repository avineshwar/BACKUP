# Lean Confluence Downloader

Simple 50-line script to download Confluence content for LLM embedding.

## Setup

```bash
pip install atlassian-python-api beautifulsoup4
```

## Usage

```bash
export CONFLUENCE_URL="https://your-domain.atlassian.net"
export CONFLUENCE_PAT="your_token"
export CONFLUENCE_SPACE_KEY="DOCS"
export MAX_WORKERS="10"  # optional, defaults to 10

python3 confluence_sync.py
```

## Output

Creates `confluence_backup/` with:
- `PageTitle/PageTitle.txt` - clean text for embedding
- `PageTitle/attachments/` - any attachments

## Tests

```bash
python3 test_confluence_sync.py
```

**Result: 14 tests, 100% pass rate**

Done. YAGNI principles applied - uses existing libraries instead of reinventing the wheel.