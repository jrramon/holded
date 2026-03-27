# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Does

CLI tool that extracts invoice data from PDF files using Gemini AI and creates expense documents in the Holded accounting platform. PDFs are converted to images via ImageMagick, sent to Gemini for structured data extraction, then pushed to Holded's API.

## Commands

```bash
# Install dependencies
bundle install

# Run the processor (use the shell wrapper which loads API keys)
./run_invoice_processor.sh invoice.pdf
./run_invoice_processor.sh /path/to/invoices/

# Run all unit tests
bundle exec ruby -I test test/test_helper.rb

# Run a single test file
bundle exec ruby -I test test/invoice_data_test.rb

# Integration tests (require valid API keys in keys/)
ruby test_holded_invoice_num.rb
ruby test_holded_with_attachment.rb
```

## Architecture

**Service layer pattern** with a CLI orchestrator:

- `invoice_processor.rb` (root) — CLI entry point. Handles args, batch processing, user confirmation, and result summaries.
- `lib/invoice_processor.rb` — Orchestrator class that coordinates extraction flow.
- `lib/gemini_image_service.rb` — Converts PDF→image (MiniMagick), encodes base64, calls Gemini API with a structured extraction prompt. Has retry logic that degrades image quality on failure.
- `lib/holded_service.rb` — Creates expense documents and attaches files via Holded REST API.
- `lib/vision_service.rb` — Google Cloud Vision OCR integration (secondary extraction method).
- `lib/invoice_data.rb` — Data model holding extracted invoice fields.

**Data flow**: PDF → image conversion → Gemini AI extraction → JSON parsing → user confirmation → Holded API expense creation + file attachment.

## Environment Variables

- `GEMINI_API` — Gemini API key (required)
- `HOLDED_API_KEY` — Holded API key (required)
- `GOOGLE_CREDENTIALS_PATH` — Google Cloud service account JSON path (for Vision API)

The shell wrapper `run_invoice_processor.sh` reads keys from `keys/gemini_api_key.txt` and `keys/holded_api_key.txt`.

## System Dependencies

ImageMagick must be installed (`brew install imagemagick` on macOS) for PDF-to-image conversion via MiniMagick.
