require 'minitest/autorun'
require 'minitest/reporters'
require 'fileutils'
require_relative '../lib/invoice_processor'
require_relative '../lib/invoice_data'
require_relative '../lib/gemini_image_service'
require_relative '../lib/holded_service'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new 