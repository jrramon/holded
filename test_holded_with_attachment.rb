#!/usr/bin/env ruby

require_relative 'lib/holded_service'

# Mock invoice data to test Holded integration
mock_invoice_data = {
  invoice_number: "2520140866",
  date: "01/04/2025",
  total_amount: 548.08,
  vendor_name: "KM Renting",
  vendor_id: "B12345678",
  line_items: [
    { 
      description: "Servicio de Renting", 
      amount: 452.96,
      tax_percentage: 21.0
    }
  ],
  tax_amount: 95.12
}

# Use the actual PDF file for attachment test
pdf_file_path = "test/invoices/KIA TA6743 mar25.pdf"

puts "🧪 Testing Holded with mock invoice data + file attachment..."
puts "📄 Invoice Number: #{mock_invoice_data[:invoice_number]}"
puts "📅 Date: #{mock_invoice_data[:date]}"
puts "💰 Total: $#{mock_invoice_data[:total_amount]}"
puts "🏢 Vendor: #{mock_invoice_data[:vendor_name]}"
puts "🆔 Vendor ID (CIF/NIF): #{mock_invoice_data[:vendor_id]}"
puts "📁 File to attach: #{pdf_file_path}"
puts

begin
  holded_service = HoldedService.new
  
  # Create the expense document
  result = holded_service.create_expense(mock_invoice_data)
  
  # Attach the original file to the document
  if result && result['id']
    puts "\n📎 Attaching original file to document..."
    begin
      holded_service.attach_file(result['id'], pdf_file_path)
      puts "🎉 Complete pipeline successful: Document created + File attached!"
    rescue => e
      puts "⚠️  Warning: Failed to attach file: #{e.message}"
      puts "📋 Document was created successfully, but file attachment failed."
    end
  else
    puts "❌ No document ID returned from Holded"
  end
  
rescue => e
  puts "❌ Failed to create expense in Holded: #{e.message}"
  puts "Error class: #{e.class}"
  puts "Backtrace: #{e.backtrace.first(3).join("\n")}"
end 