require_relative 'test_helper'
require_relative '../lib/preview_server'
require 'tmpdir'

class PreviewServerTest < Minitest::Test
  def two_jobs
    [
      {
        data: {
          invoice_number: "INV-001", date: "2026-03-15", vendor_name: "Acme Corp",
          vendor_id: "B12345678", total_amount: "1210.00", tax_amount: "210.00",
          line_items: [{ description: "Consulting", amount: "1000.00", tax_percentage: "21" }]
        },
        file_path: "/tmp/invoice1.pdf"
      },
      {
        data: {
          invoice_number: "INV-002", date: "2026-04-01", vendor_name: "Widgets Inc",
          vendor_id: "A87654321", total_amount: "605.00", tax_amount: "105.00",
          line_items: [{ description: "Widget pack", amount: "500.00", tax_percentage: "21" }]
        },
        file_path: "/tmp/invoice2.pdf"
      }
    ]
  end

  def setup_app(jobs = two_jobs)
    PreviewServer.setup_batch(jobs)
    Rack::Test::Session.new(PreviewServer)
  end

  def test_batch_shows_first_file
    session = setup_app

    session.get '/'
    assert_equal 200, session.last_response.status
    body = session.last_response.body
    assert_includes body, "INV-001"
    assert_includes body, "Acme Corp"
    assert_includes body, "invoice1.pdf"
  end

  def test_progress_indicator
    session = setup_app

    session.get '/'
    body = session.last_response.body
    assert_includes body, "File 1 of 2"
  end

  def test_confirm_advances_to_next_file
    session = setup_app

    session.post '/confirm'
    assert_equal 302, session.last_response.status

    session.get '/'
    body = session.last_response.body
    assert_includes body, "INV-002"
    assert_includes body, "Widgets Inc"
  end

  def test_cancel_advances_to_next_file
    session = setup_app

    session.post '/cancel'
    assert_equal 302, session.last_response.status

    session.get '/'
    body = session.last_response.body
    assert_includes body, "INV-002"
  end

  def test_summary_after_last_file
    session = setup_app

    session.post '/confirm'
    session.post '/cancel'
    session.get '/'

    body = session.last_response.body
    assert_includes body, "invoice1.pdf"
    assert_includes body, "invoice2.pdf"
    assert_includes body, "Confirmed"
    assert_includes body, "Cancelled"
  end

  def test_done_records_results
    session = setup_app

    session.post '/confirm'
    session.post '/cancel'
    session.post '/done'

    results = PreviewServer.results
    assert_equal 2, results.length
    assert_equal true, results[0][:confirmed]
    assert_equal "/tmp/invoice1.pdf", results[0][:file_path]
    assert_equal false, results[1][:confirmed]
  end

  def test_single_file_batch
    jobs = [two_jobs.first]
    session = setup_app(jobs)

    session.post '/confirm'
    session.get '/'

    body = session.last_response.body
    assert_includes body, "Confirmed"
    assert_includes body, "invoice1.pdf"
  end

  def test_serves_pdf_file
    pdf_path = File.join(Dir.tmpdir, "test_preview.pdf")
    File.write(pdf_path, "%PDF-1.4 fake content")

    jobs = [{ data: two_jobs.first[:data], file_path: pdf_path }]
    session = setup_app(jobs)

    session.get '/pdf'
    assert_equal 200, session.last_response.status
    assert_equal 'application/pdf', session.last_response.content_type
  ensure
    File.delete(pdf_path) if File.exist?(pdf_path)
  end

  def test_html_contains_confirm_and_cancel_buttons
    session = setup_app

    session.get '/'
    body = session.last_response.body
    assert_includes body, 'action="/confirm"'
    assert_includes body, 'action="/cancel"'
  end

  def test_html_contains_pdf_iframe
    session = setup_app

    session.get '/'
    body = session.last_response.body
    assert_includes body, '<iframe'
    assert_includes body, '/pdf'
  end

  def test_fields_are_editable_inputs
    session = setup_app

    session.get '/'
    body = session.last_response.body
    assert_includes body, 'name="invoice_number"'
    assert_includes body, 'name="vendor_name"'
    assert_includes body, 'name="date"'
    assert_includes body, 'name="total_amount"'
    assert_includes body, 'name="tax_amount"'
    assert_includes body, 'name="vendor_id"'
  end

  def test_confirm_captures_edited_data
    session = setup_app

    session.post '/confirm', {
      invoice_number: "EDITED-001",
      date: "2026-06-01",
      vendor_name: "Edited Corp",
      vendor_id: "X99999999",
      total_amount: "999.00",
      tax_amount: "99.00",
      "line_items[0][description]" => "Edited item",
      "line_items[0][amount]" => "900.00",
      "line_items[0][tax_percentage]" => "10"
    }

    result = PreviewServer.results.first
    assert_equal true, result[:confirmed]
    assert_equal "EDITED-001", result[:data][:invoice_number]
    assert_equal "Edited Corp", result[:data][:vendor_name]
    assert_equal "999.00", result[:data][:total_amount]
    assert_equal "Edited item", result[:data][:line_items].first[:description]
    assert_equal "900.00", result[:data][:line_items].first[:amount]
    assert_equal "10", result[:data][:line_items].first[:tax_percentage]
  end

  def test_cancel_keeps_original_data
    session = setup_app

    session.post '/cancel'

    result = PreviewServer.results.first
    assert_equal false, result[:confirmed]
    assert_nil result[:data]
  end

  def test_on_confirm_callback_called_immediately
    callback_received = []
    on_confirm = proc { |r| callback_received << r }

    PreviewServer.setup_batch(two_jobs, on_confirm: on_confirm)
    session = Rack::Test::Session.new(PreviewServer)

    session.post '/confirm', { invoice_number: "INV-001", date: "2026-03-15",
      vendor_name: "Acme Corp", vendor_id: "B12345678",
      total_amount: "1210.00", tax_amount: "210.00",
      "line_items[0][description]" => "Consulting",
      "line_items[0][amount]" => "1000.00",
      "line_items[0][tax_percentage]" => "21" }

    assert_equal 1, callback_received.length
    assert_equal true, callback_received.first[:confirmed]
    assert_equal "/tmp/invoice1.pdf", callback_received.first[:file_path]
  end

  def test_on_confirm_callback_not_called_on_cancel
    callback_received = []
    on_confirm = proc { |r| callback_received << r }

    PreviewServer.setup_batch(two_jobs, on_confirm: on_confirm)
    session = Rack::Test::Session.new(PreviewServer)

    session.post '/cancel'

    assert_empty callback_received
  end
end
