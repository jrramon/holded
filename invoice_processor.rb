#!/usr/bin/env ruby

require_relative 'lib/invoice_processor'
require_relative 'lib/holded_service'

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

begin
  processor = InvoiceProcessor.new(ARGV)
  puts "Processing image: #{processor.image_path}"
  
  data = processor.process_invoice
  display_preview(data)
  
  if ask_for_confirmation
    puts "Creating expense in Holded..."
    create_expense_in_holded(data, processor.image_path)
  else
    puts "Operation cancelled."
  end
rescue ArgumentError => e
  puts "Error: #{e.message}"
  exit 1
rescue => e
  puts "Unexpected error: #{e.message}"
  exit 1
end 