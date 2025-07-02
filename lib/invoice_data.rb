class InvoiceData
  attr_reader :invoice_number, :date, :total_amount, :vendor_name, :vendor_id, :line_items, :tax_amount

  def initialize(invoice_number:, date:, total_amount:, vendor_name:, vendor_id:, line_items:, tax_amount:)
    @invoice_number = invoice_number
    @date = date
    @total_amount = total_amount
    @vendor_name = vendor_name
    @vendor_id = vendor_id
    @line_items = line_items
    @tax_amount = tax_amount
  end

  def subtotal
    line_items.sum { |item| item[:amount] }
  end
end 