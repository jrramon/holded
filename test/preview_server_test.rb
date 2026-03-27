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
end
