require 'sinatra/base'
require 'erb'

class PreviewServer < Sinatra::Base
  set :server, 'webrick'
  set :logging, false
  set :host_authorization, { permitted_hosts: [] }

  class << self
    attr_accessor :jobs, :current_index, :results
  end

  def self.setup_batch(jobs)
    self.jobs = jobs
    self.current_index = 0
    self.results = []
  end

  def self.process_batch(jobs)
    setup_batch(jobs)

    port = 4567
    system("open", "http://localhost:#{port}")

    set :port, port
    run!

    results
  end

  get '/' do
    jobs = self.class.jobs
    index = self.class.current_index

    if index < jobs.length
      job = jobs[index]
      data = job[:data]
      filename = File.basename(job[:file_path])
      total = jobs.length
      position = index + 1
      ERB.new(INDEX_TEMPLATE).result(binding)
    else
      results = self.class.results
      ERB.new(SUMMARY_TEMPLATE).result(binding)
    end
  end

  get '/pdf' do
    job = self.class.jobs[self.class.current_index]
    content_type 'application/pdf'
    cache_control :no_store
    send_file job[:file_path]
  end

  post '/confirm' do
    job = self.class.jobs[self.class.current_index]
    self.class.results << { file_path: job[:file_path], confirmed: true }
    self.class.current_index += 1
    redirect '/'
  end

  post '/cancel' do
    job = self.class.jobs[self.class.current_index]
    self.class.results << { file_path: job[:file_path], confirmed: false }
    self.class.current_index += 1
    redirect '/'
  end

  post '/done' do
    self.class.quit!
    message = "All done! You can close this tab."
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
        h1 { color: #333; margin-bottom: 4px; }
        h3 { color: #555; margin-top: 20px; }
        .progress { color: #888; margin-bottom: 16px; }
      </style>
    </head>
    <body>
      <div class="pdf-panel">
        <iframe src="/pdf?t=<%= Time.now.to_i %>"></iframe>
      </div>
      <div class="form-panel">
        <h1>Invoice Preview</h1>
        <p class="progress">File <%= position %> of <%= total %> &mdash; <%= filename %></p>
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

  SUMMARY_TEMPLATE = <<~'HTML'
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Processing Summary</title>
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, sans-serif; max-width: 700px; margin: 40px auto; padding: 0 20px; }
        h1 { color: #333; margin-bottom: 20px; }
        table { width: 100%; border-collapse: collapse; margin: 16px 0; }
        th, td { padding: 10px 14px; border: 1px solid #ddd; text-align: left; }
        th { background: #f5f5f5; }
        .confirmed { color: #16a34a; font-weight: bold; }
        .cancelled { color: #dc2626; font-weight: bold; }
        .totals { margin: 20px 0; font-size: 18px; color: #333; }
        button { padding: 12px 32px; font-size: 16px; border: none; border-radius: 6px; cursor: pointer; background: #3b82f6; color: white; margin-top: 16px; }
        button:hover { background: #2563eb; }
      </style>
    </head>
    <body>
      <h1>Processing Summary</h1>
      <table>
        <tr><th>File</th><th>Status</th></tr>
        <% results.each do |r| %>
        <tr>
          <td><%= File.basename(r[:file_path]) %></td>
          <td class="<%= r[:confirmed] ? 'confirmed' : 'cancelled' %>">
            <%= r[:confirmed] ? 'Confirmed' : 'Cancelled' %>
          </td>
        </tr>
        <% end %>
      </table>
      <% confirmed_count = results.count { |r| r[:confirmed] } %>
      <% cancelled_count = results.count { |r| !r[:confirmed] } %>
      <p class="totals">
        Confirmed: <%= confirmed_count %> &mdash; Cancelled: <%= cancelled_count %> &mdash; Total: <%= results.length %>
      </p>
      <form method="post" action="/done">
        <button type="submit">Done</button>
      </form>
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
