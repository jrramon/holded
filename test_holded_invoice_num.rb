#!/usr/bin/env ruby

require_relative 'lib/holded_service'

# Mock invoice data to test Holded integration
mock_invoice_data = {
  invoice_number: "2520140866",
  date: "01/04/2025",
  total_amount: 548.08,
  vendor_name: "KM Renting",
  line_items: [
    { description: "Servicio de Renting", amount: 452.96 }
  ],
  tax_amount: 95.12
}

puts "🧪 Testing Holded with mock invoice data..."
puts "📄 Invoice Number: #{mock_invoice_data[:invoice_number]}"
puts "📅 Date: #{mock_invoice_data[:date]}"
puts "💰 Total: $#{mock_invoice_data[:total_amount]}"
puts "🏢 Vendor: #{mock_invoice_data[:vendor_name]}"
puts

begin
  holded_service = HoldedService.new
  result = holded_service.create_expense(mock_invoice_data)
  
  puts "✅ Expense created successfully in Holded!"
  puts "\n📋 Full Holded API Response:"
  puts "Response class: #{result.class}"
  puts "Response: #{result.inspect}"
  puts JSON.pretty_generate(result) if result
  
  # Check if invoiceNum was set
  if result && result['invoiceNum'] && !result['invoiceNum'].empty?
    puts "\n🎉 SUCCESS: Invoice number was set to: #{result['invoiceNum']}"
  elsif result && result['invoiceNum']
    puts "\n❌ Invoice number field is still empty: #{result['invoiceNum']}"
  else
    puts "\n❌ No invoice number field found in response"
  end
  
rescue => e
  puts "❌ Failed to create expense in Holded: #{e.message}"
  puts "Error class: #{e.class}"
  puts "Backtrace: #{e.backtrace.first(3).join("\n")}"
end 