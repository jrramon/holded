require 'base64'
require 'json'
require 'httparty'
require 'mini_magick'
require 'securerandom'

class GeminiImageService
  def initialize(api_key = nil)
    @api_key = api_key || ENV['GEMINI_API']
    @base_url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
  end

  def extract_invoice_data(file_path)
    image_path = file_path
    temp_image = nil
    begin
      if File.extname(file_path).downcase == '.pdf'
        temp_image = convert_pdf_to_image(file_path)
        image_path = temp_image
      end
      image_b64 = encode_image(image_path)
      prompt = build_prompt
      body = {
        contents: [
          {
            role: "user",
            parts: [
              { text: prompt },
              { inline_data: { mime_type: "image/jpeg", data: image_b64 } }
            ]
          }
        ]
      }
      response = HTTParty.post(
        "#{@base_url}?key=#{@api_key}",
        body: body.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      unless response.success?
        raise "Gemini API error: #{response.body}"
      end
      content = response.parsed_response.dig('candidates', 0, 'content', 'parts', 0, 'text')
      json_str = extract_json_from_text(content)
      data = JSON.parse(json_str, symbolize_names: true)
      
      # Clean vendor_id by removing hyphens
      if data[:vendor_id]
        data[:vendor_id] = data[:vendor_id].gsub('-', '')
      end
      
      data
    rescue => e
      raise "Failed to extract invoice data from Gemini: #{e.message}"
    ensure
      File.delete(temp_image) if temp_image && File.exist?(temp_image)
    end
  end

  private

  def convert_pdf_to_image(pdf_path)
    temp_image = "/tmp/invoice_#{SecureRandom.hex(8)}.jpg"
    MiniMagick::Tool::Convert.new do |convert|
      convert.density(200)
      convert.quality(90)
      convert << "#{pdf_path}[0]"
      convert << temp_image
    end
    temp_image
  end

  def encode_image(image_path)
    Base64.strict_encode64(File.read(image_path))
  end

  def build_prompt
    "You are an expert AI assistant that specializes in extracting structured data from documents. Your task is to analyze the provided invoice image and extract key information. Return the data only in a valid JSON format, following the rules and schema defined below.
Extract the following information from this invoice image and return it as JSON with these exact field names: invoice_number, date, total_amount, vendor_name, vendor_id (CIF/NIF tax identification number of the company issuing the invoice - NOT the customer), line_items (array with description, amount BEFORE taxes, and tax_percentage), tax_amount. IMPORTANT: The vendor_id should be the tax ID of the company that is sending this invoice (the supplier), never use 'B02784460' as this is the customer's ID. For line_items, the amount should be the net amount BEFORE taxes are applied. Only return the JSON.

Extraction Rules & Logic:

Vendor vs. Customer:
- The vendor is the company that issued/sent the invoice. Sometimes the information about the vendor is in a vertical text.
- The customer is the recipient of the invoice, often TAYARI, often labeled \"Bill To,\" \"Customer,\" \"Sold To,\" or \"Receptor.\"
- The vendor_name and vendor_id fields must always belong to the vendor/supplier.

Data Formatting:
- date: Must be in DD/MM/YYYY format.
- total_amount, tax_amount, line_items.amount: Must be a floating-point number (e.g., 123.45), not a string with currency symbols.
- tax_percentage: Must be a number representing the percentage (e.g., 21 for 21%).

Calculations:
- line_items.amount: This is the net price per unit before any taxes are applied (the \"base imponible\" or \"subtotal\" for the line).
- tax_amount: This is the total sum of all taxes applied on the invoice.
- total_amount: This is the final, grand total of the invoice (inclusive of all taxes and charges).

Missing Information:
- If any field's value cannot be determined from the invoice, use null as the value. Do not omit the key.

JSON Schema & Example:
- Return a single JSON object with the following exact structure and field names.

JSON:

{
  \"invoice_number\": \"INV-2025-07B\",
  \"date\": \"15/07/2025\",
  \"total_amount\": 145.20,
  \"vendor_name\": \"Supplier Solutions S.L.\",
  \"vendor_id\": \"B12345678\",
  \"tax_amount\": 25.20,
  \"line_items\": [
    {
      \"description\": \"Professional Consulting Services\",
      \"amount\": 100.00,
      \"tax_percentage\": 21
    },
    {
      \"description\": \"Cloud Storage Subscription - July\",
      \"amount\": 20.00,
      \"tax_percentage\": 21
    }
  ]
}"
  end

  def extract_json_from_text(text)
    match = text.match(/\{.*\}/m)
    match ? match[0] : text
  end
end 