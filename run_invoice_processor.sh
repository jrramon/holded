#!/bin/bash

# Invoice Processor Runner Script
# This script sets up the required environment variables and runs the invoice processor

# Default paths for API keys (modify these as needed)
GEMINI_API_KEY_PATH="${GEMINI_API_KEY_PATH:-keys/gemini_api_key.txt}"
HOLDED_API_KEY_PATH="${HOLDED_API_KEY_PATH:-keys/holded_api_key.txt}"

# Function to read API key from file
read_api_key() {
    local key_path="$1"
    local key_name="$2"
    
    if [[ -f "$key_path" ]]; then
        cat "$key_path" | tr -d '\n\r'
    else
        echo "Error: $key_name file not found at $key_path" >&2
        echo "Please create the file or set the ${key_name}_PATH environment variable" >&2
        exit 1
    fi
}

# Function to display usage
show_usage() {
    echo "Usage: $0 [OPTIONS] <file_path_or_directory>"
    echo ""
    echo "Options:"
    echo "  -h, --help                    Show this help message"
    echo "  -m, --gemini-key PATH         Path to Gemini API key file"
    echo "  -k, --holded-key PATH         Path to Holded API key file"
    echo ""
    echo "Environment Variables:"
    echo "  GEMINI_API_KEY_PATH           Path to Gemini API key file (default: keys/gemini_api_key.txt)"
    echo "  HOLDED_API_KEY_PATH           Path to Holded API key file (default: keys/holded_api_key.txt)"
    echo ""
    echo "Examples:"
    echo "  $0 invoice.pdf"
    echo "  $0 /path/to/invoices/"
    echo "  $0 --google-credentials /path/to/credentials.json invoice.pdf"
    echo "  GOOGLE_CREDENTIALS_PATH=/custom/path.json $0 invoice.pdf"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -g|--google-credentials)
            GOOGLE_CREDENTIALS_PATH="$2"
            shift 2
            ;;
        -m|--gemini-key)
            GEMINI_API_KEY_PATH="$2"
            shift 2
            ;;
        -k|--holded-key)
            HOLDED_API_KEY_PATH="$2"
            shift 2
            ;;
        -*)
            echo "Error: Unknown option $1" >&2
            show_usage
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# Check if file/directory argument is provided
if [[ $# -eq 0 ]]; then
    echo "Error: No file or directory specified" >&2
    show_usage
    exit 1
fi

TARGET_PATH="$1"

# Read API keys from files
echo "🔑 Loading API keys..."
GEMINI_API_KEY=$(read_api_key "$GEMINI_API_KEY_PATH" "Gemini API key")
HOLDED_API_KEY=$(read_api_key "$HOLDED_API_KEY_PATH" "Holded API key")

# Set environment variables
export GEMINI_API="$GEMINI_API_KEY"
export HOLDED_API_KEY="$HOLDED_API_KEY"

echo "✅ Environment variables set:"
echo "   Google Cloud: $GOOGLE_CREDENTIALS_PATH"
echo "   Gemini API: ${GEMINI_API_KEY:0:10}..."
echo "   Holded API: ${HOLDED_API_KEY:0:10}..."

# Run the invoice processor
echo ""
echo "🚀 Starting invoice processor..."
echo "📄 Target: $TARGET_PATH"
echo ""

ruby invoice_processor.rb "$TARGET_PATH" 