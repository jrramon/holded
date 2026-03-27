#!/usr/bin/env ruby

require_relative 'lib/invoice_processor'
require_relative 'lib/holded_service'
require_relative 'lib/preview_server'
require_relative 'lib/mock_gemini_service'
require 'find'

$test_mode = ARGV.delete('--test')

def find_pdf_files(directory)
  pdf_files = []
  Find.find(directory) do |path|
    if File.file?(path) && File.extname(path).downcase == '.pdf'
      pdf_files << path
    end
  end
  pdf_files.sort
end

def display_preview(data)
  puts "\nExtracted Invoice Data:"
  puts "- Invoice Number: #{data[:invoice_number]}"
  puts "- Date: #{data[:date]}"
  puts "- Vendor: #{data[:vendor_name]}"
  puts "- Vendor ID (CIF/NIF): #{data[:vendor_id]}"
  puts "- Total Amount: $#{data[:total_amount]}"
  puts "- Tax Amount: $#{data[:tax_amount]}"
  puts "- Line Items:"
  data[:line_items].each do |item|
    tax_info = item[:tax_percentage] ? " (Tax: #{item[:tax_percentage]}%)" : ""
    puts "  * #{item[:description]}: $#{item[:amount]}#{tax_info}"
  end
  puts
end

def ask_for_confirmation
  print "Create expense in Holded? (y/n): "
  STDIN.gets.chomp.downcase == 'y'
end

def create_expense_in_holded(data, original_file_path)
  holded_service = HoldedService.new
  
  # Create the expense document
  result = holded_service.create_expense(data)
  
  # Attach the original file to the document
  if result && result['id']
    puts "\n📎 Attaching original file to document..."
    begin
      holded_service.attach_file(result['id'], original_file_path)
    rescue => e
      puts "⚠️  Warning: Failed to attach file: #{e.message}"
    end
  end
  
  result
rescue => e
  puts "❌ Failed to create expense in Holded: #{e.message}"
  nil
end

def process_single_file(file_path)
  puts "\n" + "="*60
  puts "📄 Processing: #{file_path}"
  puts "="*60

  begin
    gemini = $test_mode ? MockGeminiService.new : nil
    processor = InvoiceProcessor.new([file_path], gemini_service: gemini)
    data = processor.process_invoice

    if PreviewServer.confirm?(data, file_path)
      puts "Creating expense in Holded..."
      result = create_expense_in_holded(data, file_path)
      if result
        { status: :ok, file: file_path }
      else
        { status: :wrong, file: file_path, error: "Failed to create expense in Holded" }
      end
    else
      puts "Operation cancelled for this file."
      { status: :wrong, file: file_path, error: "Operation cancelled by user" }
    end
  rescue => e
    puts "❌ Error processing #{file_path}: #{e.message}"
    { status: :wrong, file: file_path, error: e.message }
  end
end

def process_directory(directory_path)
  pdf_files = find_pdf_files(directory_path)

  if pdf_files.empty?
    puts "No PDF files found in directory: #{directory_path}"
    return
  end

  puts "📁 Found #{pdf_files.length} PDF file(s) in: #{directory_path}"
  puts "📋 Files to process:"
  pdf_files.each_with_index do |file, index|
    puts "  #{index + 1}. #{File.basename(file)}"
  end
  puts

  results = []
  pdf_files.each_with_index do |file_path, index|
    puts "\n🔄 Processing file #{index + 1} of #{pdf_files.length}"
    result = process_single_file(file_path)
    results << result
  end

  puts "\n✅ All files processed!"

  # Print summary
  puts "\n" + "="*60
  puts "📊 PROCESSING SUMMARY"
  puts "="*60

  results.each do |result|
    file_name = File.basename(result[:file])
    if result[:status] == :ok
      puts "✅ OK   - #{file_name}"
    else
      puts "❌ WRONG - #{file_name}"
      puts "         Error: #{result[:error]}" if result[:error]
    end
  end

  # Print totals
  ok_count = results.count { |r| r[:status] == :ok }
  wrong_count = results.count { |r| r[:status] == :wrong }

  puts "\n" + "-"*60
  puts "Total files: #{results.length}"
  puts "✅ Successful: #{ok_count}"
  puts "❌ Failed: #{wrong_count}"
  puts "="*60
end

def process_single_file_mode(file_path)
  puts "📄 Processing single file: #{file_path}"
  process_single_file(file_path)
end

begin
  if ARGV.empty?
    puts "Usage: ruby invoice_processor.rb <file_path_or_directory>"
    puts "  - If directory: processes all PDF files in the directory"
    puts "  - If file: processes the single PDF file"
    exit 1
  end

  path = ARGV.first
  
  unless File.exist?(path)
    puts "Error: Path not found: #{path}"
    exit 1
  end

  if File.directory?(path)
    puts "📁 Processing directory: #{path}"
    process_directory(path)
  elsif File.file?(path)
    if File.extname(path).downcase == '.pdf'
      process_single_file_mode(path)
    else
      puts "Error: File is not a PDF: #{path}"
      exit 1
    end
  else
    puts "Error: Path is neither a file nor directory: #{path}"
    exit 1
  end
  
rescue ArgumentError => e
  puts "Error: #{e.message}"
  exit 1
rescue => e
  puts "Unexpected error: #{e.message}"
  exit 1
end 