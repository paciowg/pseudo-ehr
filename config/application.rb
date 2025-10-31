require_relative 'boot'

require 'rails/all'

# Load environment variables from .env
require 'dotenv'
Dotenv.load

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Disable SSL Verification in Development
# OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?

module PseudoEhr
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    config.x.sample_data.manifest_url = 'https://paciowg.github.io/sample-data-fsh/manifest.json'

    # Disable SSL Verification in Development
    config.ssl_options = { verify_ssl: false } if Rails.env.development?

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
