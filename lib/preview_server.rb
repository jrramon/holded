require 'sinatra/base'
require 'erb'

class PreviewServer < Sinatra::Base
  set :server, 'webrick'
  set :logging, false
  set :host_authorization, { permitted_hosts: [] }

  class << self
    attr_accessor :last_result, :invoice_data, :pdf_path
  end

  def self.build_app(data, file_path)
    self.invoice_data = data
    self.pdf_path = file_path
    self.last_result = nil
    self
  end

  def self.confirm?(data, file_path)
    build_app(data, file_path)

    port = 4567
    system("open", "http://localhost:#{port}")

    set :port, port
    run!

    last_result
  end

  get '/' do
    data = self.class.invoice_data
    filename = File.basename(self.class.pdf_path)
    ERB.new(INDEX_TEMPLATE).result(binding)
  end

  get '/pdf' do
    content_type 'application/pdf'
    cache_control :no_store
    send_file self.class.pdf_path
  end

  post '/confirm' do
    self.class.last_result = true
    self.class.quit!
    message = "Confirmed! You can close this tab."
    ERB.new(DONE_TEMPLATE).result(binding)
  end

  post '/cancel' do
    self.class.last_result = false
    self.class.quit!
    message = "Cancelled. You can close this tab."
    ERB.new(DONE_TEMPLATE).result(binding)
  end

  INDEX_TEMPLATE = <<~'HTML'
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Invoice Preview</title>
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, sans-serif; display: flex; height: 100vh; overflow: hidden; }
        .pdf-panel { width: 50%; height: 100%; border-right: 2px solid #ddd; }
        .pdf-panel iframe { width: 100%; height: 100%; border: none; }
        .form-panel { width: 50%; height: 100%; overflow-y: auto; padding: 24px 32px; }
        table { width: 100%; border-collapse: collapse; margin: 16px 0; }
        th, td { padding: 8px 12px; border: 1px solid #ddd; text-align: left; }
        th { background: #f5f5f5; width: 180px; }
        .actions { display: flex; gap: 12px; margin-top: 24px; }
        button { padding: 12px 32px; font-size: 16px; border: none; border-radius: 6px; cursor: pointer; }
        .confirm { background: #22c55e; color: white; }
        .confirm:hover { background: #16a34a; }
        .cancel { background: #ef4444; color: white; }
        .cancel:hover { background: #dc2626; }
        h1 { color: #333; margin-bottom: 16px; }
        h3 { color: #555; margin-top: 20px; }
      </style>
    </head>
    <body>
      <div class="pdf-panel">
        <iframe src="/pdf?t=<%= Time.now.to_i %>"></iframe>
      </div>
      <div class="form-panel">
        <h1>Invoice Preview</h1>
        <p style="color:#666; margin-bottom:12px;"><%= filename %></p>
        <table>
          <tr><th>Invoice Number</th><td><%= data[:invoice_number] %></td></tr>
          <tr><th>Date</th><td><%= data[:date] %></td></tr>
          <tr><th>Vendor</th><td><%= data[:vendor_name] %></td></tr>
          <tr><th>Vendor ID (CIF/NIF)</th><td><%= data[:vendor_id] %></td></tr>
          <tr><th>Total Amount</th><td><%= data[:total_amount] %></td></tr>
          <tr><th>Tax Amount</th><td><%= data[:tax_amount] %></td></tr>
        </table>

        <h3>Line Items</h3>
        <table>
          <tr><th>Description</th><th>Amount</th><th>Tax %</th></tr>
          <% data[:line_items].each do |item| %>
          <tr>
            <td><%= item[:description] %></td>
            <td><%= item[:amount] %></td>
            <td><%= item[:tax_percentage] %></td>
          </tr>
          <% end %>
        </table>

        <div class="actions">
          <form method="post" action="/confirm">
            <button type="submit" class="confirm">Confirm</button>
          </form>
          <form method="post" action="/cancel">
            <button type="submit" class="cancel">Cancel</button>
          </form>
        </div>
      </div>
    </body>
    </html>
  HTML

  DONE_TEMPLATE = <<~'HTML'
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Done</title>
      <style>
        body { font-family: -apple-system, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        p { font-size: 24px; color: #333; }
      </style>
    </head>
    <body>
      <p><%= message %></p>
    </body>
    </html>
  HTML
end
