require 'httparty'
require 'json'
require 'date'

class HoldedService
  def initialize(api_key = nil)
    @api_key = api_key || ENV['HOLDED_API_KEY']
    @base_url = "https://api.holded.com/api/invoicing/v1"
    
    if @api_key.nil? || @api_key.empty?
      raise "HOLDED_API_KEY environment variable is not set"
    end
  end

  def create_expense(invoice_data)
    document_data = build_document_data(invoice_data)
    url = "#{@base_url}/documents/purchase"
    
    puts "🔍 Calling Holded API: #{url}"
    puts "🔑 Using API key: #{@api_key[0..10]}..."
    puts "📦 Request payload: #{JSON.pretty_generate(document_data)}"
    
    response = HTTParty.post(
      url,
      body: document_data.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'key' => @api_key
      }
    )
    
    puts "📊 HTTP Status: #{response.code}"
    puts "📋 Response Headers: #{response.headers}"
    
    unless response.success?
      raise "Holded API error: #{response.body}"
    end
    
    result = response.parsed_response
    puts "✅ Expense created successfully in Holded!"
    puts "📄 Document ID: #{result['id']}"
    puts "📋 Full Holded API Response:"
    puts JSON.pretty_generate(result)
    
    result
  end

  def attach_file(document_id, file_path, doc_type = 'purchase')
    url = "#{@base_url}/documents/#{doc_type}/#{document_id}/attach"
    
    puts "📎 Attaching file to document: #{url}"
    puts "📁 File: #{file_path}"
    
    unless File.exist?(file_path)
      raise "File not found: #{file_path}"
    end
    
    response = HTTParty.post(
      url,
      body: { file: File.open(file_path) },
      headers: {
        'key' => @api_key
      }
    )
    
    puts "📊 HTTP Status: #{response.code}"
    
    unless response.success?
      raise "Holded API error: #{response.body}"
    end
    
    result = response.parsed_response
    puts "✅ File attached successfully!"
    puts "📋 Attachment Response:"
    puts JSON.pretty_generate(result)
    
    result
  end

  private

  def build_document_data(invoice_data)
    {
      docType: 'purchase',
      date: format_date(invoice_data[:date]),
      total: invoice_data[:total_amount],
      items: build_items(invoice_data[:line_items]),
      notes: "Invoice: #{invoice_data[:invoice_number]}",
      contactName: invoice_data[:vendor_name],
      invoiceNum: invoice_data[:invoice_number],
      contactCode: invoice_data[:vendor_id]
    }
  end

  def format_date(date_string)
    # Convert from DD/MM/YYYY to YYYY-MM-DD
    if date_string.match(/\d{2}\/\d{2}\/\d{4}/)
      day, month, year = date_string.split('/')
      "#{year}-#{month}-#{day}"
    else
      date_string
    end
  end

  def build_items(line_items)
    line_items.map do |item|
      item_data = {
        name: item[:description],
        subtotal: item[:amount],
        quantity: 1
      }
      
      # Add tax percentage if available
      if item[:tax_percentage]
        item_data[:tax] = item[:tax_percentage]
      end
      
      item_data
    end
  end
end 