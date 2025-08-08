require 'active_support/core_ext/integer/time'

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing
  config.server_timing = true

  # Use the async job adapter
  config.active_job.queue_adapter = :async

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  config.action_controller.perform_caching = true
  config.action_controller.enable_fragment_cache_logging = true

  # Configure memcached for development with optimized settings
  # config.cache_store = :mem_cache_store,
  #                      '127.0.0.1:11211',
  #                      {
  #                        namespace: 'pseudo_ehr_dev',
  #                        expires_in: 1.hour,
  #                        compress: true,
  #                        compress_threshold: 1.kilobyte,
  #                        pool_size: 5,
  #                        failover: true,
  #                        socket_timeout: 0.5,           # Reduced from 1.5 for faster response
  #                        socket_failure_delay: 0.1,     # Reduced from 0.2 for faster failover
  #                        down_retry_delay: 30,          # Reduced from 60 for faster recovery
  #                        error_when_client_sharing: false,
  #                        value_max_bytes: 2000.megabytes, # Increased max value size
  #                        cache_nils: true,              # Cache nil values to avoid repeated lookups
  #                        retry_count: 2,                # Retry failed operations
  #                        keepalive: true                # Keep connections alive
  #                      }

  if Rails.root.join('tmp/caching-dev.txt').exist?
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}"
    }
  end

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Allow Action Cable access from any origin
  config.action_cable.disable_request_forgery_protection = true

  # Set default URL options for the development environment
  config.default_url_options = { host: 'localhost:3000' }
end
