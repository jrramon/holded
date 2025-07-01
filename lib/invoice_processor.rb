require 'fileutils'
require_relative 'gemini_image_service'

class InvoiceProcessor
  attr_reader :image_path

  def initialize(args, gemini_service: nil)
    validate_arguments(args)
    @image_path = args.first
    @gemini_service = gemini_service
  end

  def process_invoice
    service = @gemini_service || GeminiImageService.new
    service.extract_invoice_data(@image_path)
  end

  private

  def validate_arguments(args)
    if args.empty?
      raise ArgumentError, "Usage: ruby invoice_processor.rb <image_path>"
    end

    unless File.exist?(args.first)
      raise ArgumentError, "File not found: #{args.first}"
    end
  end
end 