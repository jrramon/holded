require_relative 'test_helper'
require_relative '../lib/preview_server'
require 'net/http'

class PreviewServerTest < Minitest::Test
  def sample_data
    {
      invoice_number: "INV-001",
      date: "2026-03-15",
      vendor_name: "Acme Corp",
      vendor_id: "B12345678",
      total_amount: "1210.00",
      tax_amount: "210.00",
      line_items: [
        { description: "Consulting services", amount: "1000.00", tax_percentage: "21" }
      ]
    }
  end

  def test_html_contains_invoice_data
    app = PreviewServer.build_app(sample_data, "/tmp/fake.pdf")
    session = Rack::Test::Session.new(app)
    session.get '/'

    assert_equal 200, session.last_response.status
    body = session.last_response.body
    assert_includes body, "fake.pdf"
    assert_includes body, "INV-001"
    assert_includes body, "2026-03-15"
    assert_includes body, "Acme Corp"
    assert_includes body, "B12345678"
    assert_includes body, "1210.00"
    assert_includes body, "210.00"
    assert_includes body, "Consulting services"
  end

  def test_html_contains_confirm_and_cancel_buttons
    app = PreviewServer.build_app(sample_data, "/tmp/fake.pdf")
    session = Rack::Test::Session.new(app)
    session.get '/'

    body = session.last_response.body
    assert_includes body, 'action="/confirm"'
    assert_includes body, 'action="/cancel"'
  end

  def test_confirm_returns_true
    app = PreviewServer.build_app(sample_data, "/tmp/fake.pdf")
    session = Rack::Test::Session.new(app)
    session.post '/confirm'

    assert_equal 200, session.last_response.status
    assert PreviewServer.last_result
  end

  def test_cancel_returns_false
    app = PreviewServer.build_app(sample_data, "/tmp/fake.pdf")
    session = Rack::Test::Session.new(app)
    session.post '/cancel'

    assert_equal 200, session.last_response.status
    refute PreviewServer.last_result
  end

  def test_html_contains_pdf_iframe
    app = PreviewServer.build_app(sample_data, "/tmp/fake.pdf")
    session = Rack::Test::Session.new(app)
    session.get '/'

    body = session.last_response.body
    assert_includes body, '<iframe'
    assert_includes body, '/pdf'
  end

  def test_serves_pdf_file
    pdf_path = File.join(Dir.tmpdir, "test_preview.pdf")
    File.write(pdf_path, "%PDF-1.4 fake content")

    app = PreviewServer.build_app(sample_data, pdf_path)
    session = Rack::Test::Session.new(app)
    session.get '/pdf'

    assert_equal 200, session.last_response.status
    assert_equal 'application/pdf', session.last_response.content_type
  ensure
    File.delete(pdf_path) if File.exist?(pdf_path)
  end
end
