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

def extract_data(file_path)
  gemini = $test_mode ? MockGeminiService.new : nil
  processor = InvoiceProcessor.new([file_path], gemini_service: gemini)
  processor.process_invoice
end

def create_expense_in_holded(data, original_file_path)
  holded_service = HoldedService.new

  result = holded_service.create_expense(data)

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

def process_files(file_paths)
  # Extract data for all files
  jobs = []
  file_paths.each do |file_path|
    puts "🔍 Extracting data from: #{File.basename(file_path)}"
    begin
      data = extract_data(file_path)
      jobs << { data: data, file_path: file_path }
    rescue => e
      puts "❌ Error extracting #{File.basename(file_path)}: #{e.message}"
    end
  end

  return if jobs.empty?

  # Open browser for review
  batch_results = PreviewServer.process_batch(jobs)

  # Process confirmed files
  results = []
  batch_results.each do |r|
    file_path = r[:file_path]
    file_name = File.basename(file_path)
    if r[:confirmed]
      puts "\nCreating expense in Holded for #{file_name}..."
      data = jobs.find { |j| j[:file_path] == file_path }[:data]
      result = create_expense_in_holded(data, file_path)
      if result
        results << { status: :ok, file: file_path }
      else
        results << { status: :wrong, file: file_path, error: "Failed to create expense" }
      end
    else
      results << { status: :wrong, file: file_path, error: "Cancelled by user" }
    end
  end

  print_summary(results)
end

def print_summary(results)
  return if results.empty?

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

  ok_count = results.count { |r| r[:status] == :ok }
  wrong_count = results.count { |r| r[:status] == :wrong }

  puts "\n" + "-"*60
  puts "Total files: #{results.length}"
  puts "✅ Successful: #{ok_count}"
  puts "❌ Failed: #{wrong_count}"
  puts "="*60
end

begin
  if ARGV.empty?
    puts "Usage: ruby invoice_processor.rb [--test] <file_path_or_directory>"
    puts "  --test: use mock data instead of Gemini API"
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
    pdf_files = find_pdf_files(path)
    if pdf_files.empty?
      puts "No PDF files found in directory: #{path}"
      exit 1
    end
    puts "📁 Found #{pdf_files.length} PDF file(s) in: #{path}"
    pdf_files.each_with_index { |f, i| puts "  #{i + 1}. #{File.basename(f)}" }
    puts
    process_files(pdf_files)
  elsif File.file?(path)
    if File.extname(path).downcase == '.pdf'
      process_files([path])
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
