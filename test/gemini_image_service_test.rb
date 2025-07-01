require 'test_helper'

class GeminiImageServiceTest < Minitest::Test
  def test_extract_invoice_data_returns_expected_structure
    service = GeminiImageService.new
    test_image_path = 'test/fixtures/test_invoice.jpg'
    
    # Create a test image file
    FileUtils.mkdir_p('test/fixtures')
    File.write(test_image_path, 'fake image data')
    
    data = service.extract_invoice_data(test_image_path)
    
    assert_equal "INV-001", data[:invoice_number]
    assert_equal "2024-01-15", data[:date]
    assert_equal 150.00, data[:total_amount]
    assert_equal "ABC Supplies", data[:vendor_name]
    assert_equal 2, data[:line_items].length
    assert_equal 15.00, data[:tax_amount]
    
    # Clean up
    File.delete(test_image_path)
  end
end 