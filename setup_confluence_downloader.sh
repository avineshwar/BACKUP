#!/bin/bash

# Enhanced Confluence Content Downloader Setup Script
# This script sets up the environment and dependencies for the Confluence downloader

set -e  # Exit on any error

echo "🚀 Enhanced Confluence Content Downloader Setup"
echo "================================================"

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.8 or later."
    exit 1
fi

PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
echo "✅ Python $PYTHON_VERSION detected"

# Check if pip is available
if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 is not installed. Please install pip3."
    exit 1
fi

echo "✅ pip3 available"

# Create virtual environment (optional but recommended)
read -p "📦 Create a virtual environment? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ ! -d "venv" ]; then
        echo "📦 Creating virtual environment..."
        python3 -m venv venv
    fi
    echo "📦 Activating virtual environment..."
    source venv/bin/activate
    echo "✅ Virtual environment activated"
fi

# Install dependencies
echo "📦 Installing Python dependencies..."
pip3 install -r requirements.txt

echo "✅ Dependencies installed successfully"

# Create environment file template
if [ ! -f ".env" ]; then
    echo "📝 Creating .env template file..."
    cat > .env << 'EOF'
# Confluence Configuration
# Copy this file and fill in your actual values

# Your Confluence instance URL
CONFLUENCE_URL=https://your-domain.atlassian.net/wiki

# Your Personal Access Token (PAT)
# Get this from: Atlassian Account Settings > Security > API tokens
CONFLUENCE_PAT=your_personal_access_token_here

# The space key you want to download
CONFLUENCE_SPACE_KEY=YOUR_SPACE_KEY

# Output directory for downloaded content
OUTPUT_FOLDER=./confluence_backup

# Number of parallel download threads (adjust based on your system and API limits)
MAX_WORKERS=10

# Skip already downloaded files (for resumable downloads)
SKIP_EXISTING=true
EOF
    echo "✅ Created .env template file"
    echo "📝 Please edit .env file with your actual Confluence details"
else
    echo "✅ .env file already exists"
fi

# Make scripts executable
chmod +x confluence_downloader.py
chmod +x test_confluence_setup.py

echo ""
echo "🎉 Setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Edit the .env file with your Confluence details:"
echo "   nano .env"
echo ""
echo "2. Load environment variables:"
echo "   source .env"
echo ""
echo "3. Test your configuration:"
echo "   python3 test_confluence_setup.py"
echo ""
echo "4. Start downloading:"
echo "   python3 confluence_downloader.py"
echo ""
echo "📚 For detailed usage instructions, see: CONFLUENCE_README.md"
echo ""

# Optional: Test if current environment variables are set
if [ -n "$CONFLUENCE_PAT" ] && [ -n "$CONFLUENCE_URL" ] && [ -n "$CONFLUENCE_SPACE_KEY" ]; then
    echo "🔍 Detected existing environment variables. Running quick test..."
    python3 test_confluence_setup.py
fi