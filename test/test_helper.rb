ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'color_pound_spec_reporter'

Capybara.default_max_wait_time = 10
Minitest::Reporters.use! [ColorPoundSpecReporter.new]
class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
end
