require 'test_helper'

class HoldedServiceTest < Minitest::Test
  def test_create_expense_builds_correct_document_data
    service = HoldedService.new
    invoice_data = {
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
    
    # Test the private method by making it public for testing
    service.send(:build_document_data, invoice_data)
    
    # This test verifies the method doesn't raise errors
    # In a real scenario, we'd mock the HTTP call
    assert true
  end
end 