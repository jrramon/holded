require 'test_helper'

class InvoiceDataTest < Minitest::Test
  def test_creates_invoice_data_with_valid_fields
    data = InvoiceData.new(
      invoice_number: "INV-001",
      date: "2024-01-15",
      total_amount: 150.00,
      vendor_name: "ABC Supplies",
      vendor_id: "B12345678",
      line_items: [
        { description: "Office supplies", amount: 100.00, tax_percentage: 21.0 },
        { description: "Shipping", amount: 50.00, tax_percentage: 21.0 }
      ],
      tax_amount: 15.00
    )

    assert_equal "INV-001", data.invoice_number
    assert_equal "2024-01-15", data.date
    assert_equal 150.00, data.total_amount
    assert_equal "ABC Supplies", data.vendor_name
    assert_equal "B12345678", data.vendor_id
    assert_equal 2, data.line_items.length
    assert_equal 15.00, data.tax_amount
  end

  def test_validates_required_fields
    assert_raises(ArgumentError) do
      InvoiceData.new(
        invoice_number: "INV-001",
        # Missing other required fields
      )
    end
  end

  def test_calculates_subtotal_from_line_items
    data = InvoiceData.new(
      invoice_number: "INV-001",
      date: "2024-01-15",
      total_amount: 150.00,
      vendor_name: "ABC Supplies",
      vendor_id: "B12345678",
      line_items: [
        { description: "Office supplies", amount: 100.00, tax_percentage: 21.0 },
        { description: "Shipping", amount: 50.00, tax_percentage: 21.0 }
      ],
      tax_amount: 15.00
    )

    assert_equal 150.00, data.subtotal
  end
end 