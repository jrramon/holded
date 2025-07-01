require 'test_helper'
require 'ostruct'

class VisionServiceTest < Minitest::Test
  class DummyClient
    def text_detection(image:)
      OpenStruct.new(
        responses: [OpenStruct.new(full_text_annotation: OpenStruct.new(text: "Invoice number: INV-001\nDate: 2024-01-15\nTotal: 150.00\nVendor: ABC Supplies\nItem: Office supplies 100.00\nItem: Shipping 50.00\nTax: 15.00"))]
      )
    end
  end

  def test_extract_text_returns_expected_string
    service = VisionService.new(DummyClient.new)
    text = service.extract_text('fake_path.jpg')
    assert_includes text, "Invoice number: INV-001"
    assert_includes text, "Total: 150.00"
    assert_includes text, "Tax: 15.00"
  end
end 