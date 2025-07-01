#!/usr/bin/env ruby

require_relative 'lib/invoice_processor'
require_relative 'lib/holded_service'

def display_preview(data)
  puts "\nExtracted Invoice Data:"
  puts "- Invoice Number: #{data[:invoice_number]}"
  puts "- Date: #{data[:date]}"
  puts "- Vendor: #{data[:vendor_name]}"
  puts "- Total Amount: $#{data[:total_amount]}"
  puts "- Tax Amount: $#{data[:tax_amount]}"
  puts "- Line Items:"
  data[:line_items].each do |item|
    puts "  * #{item[:description]}: $#{item[:amount]}"
  end
  puts
end

def ask_for_confirmation
  print "Create expense in Holded? (y/n): "
  STDIN.gets.chomp.downcase == 'y'
end

def create_expense_in_holded(data)
  holded_service = HoldedService.new
  result = holded_service.create_expense(data)
  puts "✅ Expense created successfully in Holded!"
  puts "\n📋 Full Holded API Response:"
  puts JSON.pretty_generate(result)
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
    create_expense_in_holded(data)
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