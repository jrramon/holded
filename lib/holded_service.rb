require 'httparty'
require 'json'
require 'date'

class HoldedService
  def initialize(api_key = nil)
    @api_key = api_key || ENV['HOLDED_API_KEY']
    @base_url = "https://api.holded.com/api/invoicing/v1"
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
    
    response.parsed_response
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
      number: invoice_data[:invoice_number],
      invoiceNumber: invoice_data[:invoice_number]
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
      {
        name: item[:description],
        price: item[:amount],
        quantity: 1
      }
    end
  end
end 