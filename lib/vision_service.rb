require 'google/cloud/vision/v1'

class VisionService
  def initialize(client = nil)
    @client = client || Google::Cloud::Vision::V1::ImageAnnotator::Client.new
  end

  def extract_text(image_path)
    response = @client.text_detection image: image_path
    annotation = response.responses.first
    annotation&.full_text_annotation&.text || ""
  rescue => e
    raise "Failed to extract text from image: #{e.message}"
  end
end 