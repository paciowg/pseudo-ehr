require 'nokogiri'
require 'open-uri'
require 'json'
require 'fileutils'

namespace :sample_data do
  desc 'Scrape FHIR resources from the published IG page and organize them by scene and resource type'
  task scrape: :environment do
    puts 'Starting to scrape FHIR resources...'

    # URL of the published IG page
    ig_url = 'https://build.fhir.org/ig/paciowg/sample-data-fsh/pacio_persona_betsySmithJohnson.html'

    # Create the base directory for sample use cases if it doesn't exist
    base_dir = Rails.root.join('sample_use_cases')
    FileUtils.mkdir_p(base_dir)

    # Use case title (extracted from the page title)

    begin
      # Parse the IG page
      puts 'Fetching and parsing the IG page...'
      doc = Nokogiri::HTML(URI.open(ig_url))
      puts 'Successfully parsed the IG page'

      # Extract the use case title from the page title
      page_title = doc.css('title').text.strip
      use_case_title = page_title.include?(' - ') ? page_title.split(' - ')[0].strip : 'Betsy Smith-Johnson - Stroke Use Case'
      puts "Use case title: #{use_case_title}"

      # Create directory for this use case
      use_case_dir = File.join(base_dir, use_case_title)
      FileUtils.mkdir_p(use_case_dir)

      # Find all scene data summary sections
      puts 'Looking for scene data summary sections...'
      scene_headers = doc.css('h2, h3, h4').select { |h| h.text.strip.match(/Scene \d+ Sample Data Summary/i) }
      puts "Found #{scene_headers.length} scene data summary sections"

      scene_headers.each do |scene_header|
        scene_title = scene_header.text.strip
        scene_number = scene_title.scan(/\d+/).first || '0'

        puts "Processing #{scene_title}..."

        # Create directory for this scene
        scene_dir = File.join(use_case_dir, "scene_#{scene_number}")
        FileUtils.mkdir_p(scene_dir)

        # Find the unordered list that follows the scene header
        resource_list = nil
        current_element = scene_header.next_element

        # Look for the first unordered list after the scene header
        while current_element && !resource_list
          resource_list = current_element if current_element.name == 'ul'
          current_element = current_element.next_element
        end

        if resource_list
          puts "  Found resource list with #{resource_list.css('li').length} items"

          # Process each list item (resource link)
          resource_list.css('li a').each do |resource_link|
            resource_name = resource_link.text.strip
            resource_page_url = resource_link['href']

            # Make the URL absolute if it's relative
            unless resource_page_url.start_with?('http')
              resource_page_url = URI.join(ig_url,
                                           resource_page_url).to_s
            end

            puts "  Processing resource: #{resource_name} (#{resource_page_url})"

            # Navigate to the resource page
            resource_page = Nokogiri::HTML(URI.open(resource_page_url))

            # Find the JSON tab link
            json_tab_link = resource_page.css('a').find { |a| a.text.strip.downcase == 'json' }

            if json_tab_link
              json_tab_url = json_tab_link['href']
              unless json_tab_url.start_with?('http')
                json_tab_url = URI.join(resource_page_url,
                                        json_tab_url).to_s
              end

              puts "    Found JSON tab: #{json_tab_url}"

              # Navigate to the JSON tab
              Nokogiri::HTML(URI.open(json_tab_url))

              # Get the JSON directly by removing the .html suffix from the JSON tab URL
              json_url = json_tab_url.gsub('.html', '')
              puts "    Getting JSON from: #{json_url}"

              begin
                # Download the JSON file
                resource_json = URI.open(json_url).read
                resource_data = JSON.parse(resource_json)

                # Extract resource type
                resource_type = resource_data['resourceType']

                # Create directory for this resource type if it doesn't exist
                resource_type_dir = File.join(scene_dir, resource_type)
                FileUtils.mkdir_p(resource_type_dir)

                # Extract resource ID or generate a filename
                resource_id = resource_data['id'] || resource_name.gsub(/\s+/, '_')
                filename = "#{resource_id}.json"

                # Save the resource
                File.write(File.join(resource_type_dir, filename), JSON.pretty_generate(resource_data))
                puts "    Saved #{resource_type}/#{filename}"
              rescue StandardError => e
                puts "    Error downloading JSON: #{e.message}"
              end
            else
              puts '    No JSON tab found'
            end
          rescue StandardError => e
            puts "    Error processing resource #{resource_name}: #{e.message}"
          end
        else
          puts '  No resource list found for this scene'
        end
      end

      puts "Completed scraping FHIR resources for #{use_case_title}"

      # Check if any resources were downloaded
      total_resources = Dir.glob(File.join(base_dir, '**', '*.json')).count
      puts "Total resources downloaded: #{total_resources}"
      if total_resources.zero?
        puts 'WARNING: No resources were downloaded. This could be due to:'
        puts "1. The page structure has changed and the script couldn't find the scene sections"
        puts '2. No resource links were found in the scene sections'
        puts '3. There was an issue downloading or processing the resources'
        puts "Try visiting #{ig_url} manually to verify the page structure and resource links"
      end
    rescue StandardError => e
      puts "Error scraping FHIR resources: #{e.message}"
      puts e.backtrace
    end
  end
end
