namespace :fhir do
  # A simple object that mimics TaskStatus for console output
  class ConsoleTaskStatus
    def update_status(_status, message)
      puts message
    end
  end

  desc 'Push FHIR sample data resources to a FHIR server'
  task :push, %i[release_tag fhir_server_url] => :environment do |_t, args|
    release_tag = args[:release_tag]
    fhir_server_url = args[:fhir_server_url]

    if release_tag.nil? || fhir_server_url.nil?
      puts 'Usage: bundle exec rake fhir:push[release_tag,fhir_server_url]'
      puts 'Example: bundle exec rake "fhir:push[master,http://hapi.fhir.org/baseR4]"'
      puts 'See https://paciowg.github.io/sample-data-fsh/ for sample data release information'
      exit 1
    end

    resource_urls = SampleDataService.version_resource_urls(release_tag)

    if resource_urls.empty?
      puts "No resource URLs found for release tag #{release_tag}"
      exit 1
    end

    FhirPushService.perform(resource_urls, fhir_server_url, ConsoleTaskStatus.new)
  end
end
