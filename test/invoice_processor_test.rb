require 'test_helper'

class InvoiceProcessorTest < Minitest::Test
  class DummyGeminiService
    def extract_invoice_data(_image_path)
      {
        invoice_number: "INV-001",
        date: "2024-01-15",
        total_amount: 150.00,
        vendor_name: "ABC Supplies",
        line_items: [
          { description: "Office supplies", amount: 100.00 },
          { description: "Shipping", amount: 50.00 }
        ],
        tax_amount: 15.00
      }
    end
  end

  def test_raises_error_when_no_arguments_provided
    assert_raises(ArgumentError) do
      InvoiceProcessor.new([])
    end
  end

  def test_raises_error_when_file_does_not_exist
    assert_raises(ArgumentError) do
      InvoiceProcessor.new(['nonexistent_file.jpg'])
    end
  end

  def test_accepts_valid_image_file
    test_image_path = 'test/fixtures/test_invoice.jpg'
    FileUtils.mkdir_p('test/fixtures')
    File.write(test_image_path, 'fake image data')
    
    processor = InvoiceProcessor.new([test_image_path])
    assert_equal test_image_path, processor.image_path
    
    File.delete(test_image_path)
  end

  def test_process_invoice_with_gemini_service
    test_image_path = 'test/fixtures/test_invoice.jpg'
    FileUtils.mkdir_p('test/fixtures')
    File.write(test_image_path, 'fake image data')

    processor = InvoiceProcessor.new(
      [test_image_path],
      gemini_service: DummyGeminiService.new
    )
    data = processor.process_invoice
    assert_equal "INV-001", data[:invoice_number]
    assert_equal "2024-01-15", data[:date]
    assert_equal 150.00, data[:total_amount]
    assert_equal "ABC Supplies", data[:vendor_name]
    assert_equal 2, data[:line_items].length
    assert_equal 15.00, data[:tax_amount]

    File.delete(test_image_path)
  end
end 