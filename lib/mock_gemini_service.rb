class MockGeminiService
  def extract_invoice_data(_file_path)
    {
      invoice_number: "TEST-#{rand(1000..9999)}",
      date: "15/03/2026",
      vendor_name: "Proveedor Test S.L.",
      vendor_id: "B98765432",
      total_amount: 1210.00,
      tax_amount: 210.00,
      line_items: [
        { description: "Servicio de consultoría", amount: 800.00, tax_percentage: 21 },
        { description: "Licencia software mensual", amount: 200.00, tax_percentage: 21 }
      ]
    }
  end
end
