# Invoice Processor

A Ruby application that processes invoice images/PDFs, extracts data using Google Cloud Vision and Gemini AI, and creates expenses in Holded via their API.

## Features

- 📄 Process PDF invoices (converts to images automatically)
- 🤖 AI-powered data extraction using Google Cloud Vision + Gemini
- 💰 Automatic expense creation in Holded
- 📎 File attachment to Holded documents
- 🌐 Browser-based preview with embedded PDF viewer and extracted data side by side
- 📁 Batch processing of multiple files in a single browser session
- 🧪 Test mode (`--test`) to preview UI without consuming API tokens

## Setup

### 1. Install Dependencies

```bash
bundle install
```

### 2. Install System Dependencies

The application requires ImageMagick for PDF processing:

```bash
# macOS
brew install imagemagick

# Ubuntu/Debian
sudo apt-get install imagemagick

# CentOS/RHEL
sudo yum install ImageMagick
```

### 3. Configure API Keys

Create the following files in the `keys/` directory:

#### Gemini API Key
- File: `keys/gemini_api_key.txt`
- Content: Your Gemini API key (just the key, no extra formatting)

#### Holded API Key
- File: `keys/holded_api_key.txt`
- Content: Your Holded API key (just the key, no extra formatting)

## Usage

### Using the Runner Script (Recommended)

The easiest way to run the processor is using the provided shell script:

```bash
# Process a single PDF file
./run_invoice_processor.sh invoice.pdf

# Process all PDF files in a directory
./run_invoice_processor.sh /path/to/invoices/

# Use custom API key paths
./run_invoice_processor.sh --google-credentials /path/to/credentials.json \
                          --gemini-key /path/to/gemini.txt \
                          --holded-key /path/to/holded.txt \
                          invoice.pdf

# Using environment variables
GOOGLE_CREDENTIALS_PATH=/custom/path.json \
GEMINI_API_KEY_PATH=/custom/gemini.txt \
HOLDED_API_KEY_PATH=/custom/holded.txt \
./run_invoice_processor.sh invoice.pdf
```

### Direct Ruby Execution

You can also run the processor directly with Ruby, but you'll need to set environment variables manually:

```bash
export GEMINI_API="$(cat keys/gemini_api_key.txt)"
export HOLDED_API_KEY="$(cat keys/holded_api_key.txt)"

ruby invoice_processor.rb invoice.pdf

# Test mode (mock Gemini data, no API tokens spent)
ruby invoice_processor.rb --test invoice.pdf
ruby invoice_processor.rb --test /path/to/invoices/
```

## How It Works

1. **PDF Processing**: Converts PDF to high-quality image using ImageMagick
2. **Data Extraction**: Sends image to Gemini AI for structured data extraction
3. **Browser Preview**: Opens a local web page with the PDF on the left and extracted data on the right. For batch processing, all files are reviewed in a single browser session with automatic navigation between files.
4. **Holded Integration**: Creates expense document in Holded for each confirmed invoice
5. **File Attachment**: Attaches the original PDF to the Holded document
6. **Summary**: Shows processing results both in the browser and in the terminal

## Extracted Data Fields

The AI extracts the following information from invoices:

- `invoice_number`: Invoice identifier
- `date`: Invoice date (DD/MM/YYYY format)
- `total_amount`: Total invoice amount
- `vendor_name`: Supplier company name
- `vendor_id`: Supplier tax ID (CIF/NIF)
- `tax_amount`: Total tax amount
- `line_items`: Array of items with description, amount, and tax percentage

## Troubleshooting

### Common Issues

1. **ImageMagick not found**: Install ImageMagick using your package manager
2. **API key errors**: Ensure API key files exist and contain valid keys
3. **Permission denied**: Make sure the script is executable: `chmod +x run_invoice_processor.sh`
4. **Google Cloud credentials**: Ensure the service account has Vision API access

### Debug Mode

The application includes extensive logging. Check the console output for detailed information about each step.

## File Structure

```
holded/
├── run_invoice_processor.sh    # Main runner script
├── invoice_processor.rb        # Main processor
├── lib/                        # Service classes
│   ├── vision_service.rb       # Google Cloud Vision integration
│   ├── gemini_image_service.rb # Gemini AI integration
│   ├── holded_service.rb       # Holded API integration
│   ├── invoice_processor.rb    # Core processing logic
│   ├── preview_server.rb       # Sinatra-based browser preview
│   └── mock_gemini_service.rb  # Mock service for --test mode
├── keys/                       # API keys and credentials
│   ├── arimidori-7a49f7f94661.json
│   ├── gemini_api_key.txt
│   └── holded_api_key.txt
└── test/                       # Test files
    └── invoices/               # Sample invoices for testing
```

## Testing

Run the test suite:

```bash
bundle exec ruby -I test test/test_helper.rb
```

## Security Notes

- Never commit API keys to version control
- Use environment variables or secure key management in production
- The `keys/` directory should be added to `.gitignore`
- Consider using a secrets management service for production deployments 