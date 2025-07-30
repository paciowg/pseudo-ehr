# This rake task extracts conformance requirements from a FHIR capability statement
# and writes them to an Excel file.
#
# Usage:
# rake "capability_statement:extract_requirements[path/to/capability_statement.json]"

require 'json'
require 'caxlsx'

namespace :capability_statement do
  desc 'Extract conformance requirements from a FHIR capability statement and write to Excel'
  task :extract_requirements, [:file_path] => :environment do |_t, args|
    file_path = args[:file_path]

    unless file_path && File.exist?(file_path)
      puts 'Error: Please provide a valid file path to a capability statement JSON file.'
      puts 'Usage: rake capability_statement:extract_requirements[path/to/capability_statement.json]'
      exit 1
    end

    # Parse the capability statement JSON
    begin
      capability_statement = JSON.parse(File.read(file_path))
    rescue JSON::ParserError => e
      puts "Error parsing JSON file: #{e.message}"
      exit 1
    end

    # Extract the title and convert to snake case for the output filename
    title = capability_statement['title'] || capability_statement['name'] || 'capability_statement'
    output_filename = title.to_s.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_|_$/, '')
    output_path = File.join('requirements', "#{output_filename}.xlsx")

    # Get the URL of the capability statement
    url = capability_statement['url'] || file_path

    # Extract requirements
    requirements = []

    # Process REST resources
    capability_statement['rest']&.each do |rest|
      actor = rest['mode'] # server or client

      # Extract documentation requirements
      extract_requirements_from_text(rest['documentation'], url, actor, requirements) if rest['documentation']

      # Extract security requirements
      if rest['security'] && rest['security']['description']
        extract_requirements_from_text(rest['security']['description'], url, actor, requirements)
      end

      # Extract resource requirements
      next unless rest['resource']

      rest['resource'].each do |resource|
        resource_type = resource['type']

        # Check resource conformance extension
        resource_conformance = 'MAY'
        resource['extension']&.each do |ext|
          if ext['url'] == 'http://hl7.org/fhir/StructureDefinition/capabilitystatement-expectation'
            resource_conformance = ext['valueCode']
          end
        end

        # Add resource-level requirement
        requirements << {
          url: url,
          requirement: "Support #{resource_type} resource",
          conformance: resource_conformance,
          actor: actor
        }

        # Extract interaction requirements
        resource['interaction']&.each do |interaction|
          interaction_conformance = 'MAY'
          interaction['extension']&.each do |ext|
            if ext['url'] == 'http://hl7.org/fhir/StructureDefinition/capabilitystatement-expectation'
              interaction_conformance = ext['valueCode']
            end
          end

          requirements << {
            url: url,
            requirement: "Support #{interaction['code']} interaction on #{resource_type}",
            conformance: interaction_conformance,
            actor: actor
          }
        end

        # Extract search parameter requirements
        resource['searchParam']&.each do |param|
          param_conformance = 'MAY'
          param['extension']&.each do |ext|
            if ext['url'] == 'http://hl7.org/fhir/StructureDefinition/capabilitystatement-expectation'
              param_conformance = ext['valueCode']
            end
          end

          requirements << {
            url: url,
            requirement: "Support search parameter '#{param['name']}' on #{resource_type}",
            conformance: param_conformance,
            actor: actor
          }
        end

        # Extract operation requirements
        next unless resource['operation']

        resource['operation'].each do |operation|
          op_conformance = 'MAY'
          operation['extension']&.each do |ext|
            if ext['url'] == 'http://hl7.org/fhir/StructureDefinition/capabilitystatement-expectation'
              op_conformance = ext['valueCode']
            end
          end

          requirements << {
            url: url,
            requirement: "Support operation '#{operation['name']}' on #{resource_type}",
            conformance: op_conformance,
            actor: actor
          }
        end
      end
    end

    # Deduplicate requirements before writing to Excel
    unique_requirements = []
    seen_requirements = Set.new

    requirements.each do |req|
      # Create a normalized version of the requirement for comparison
      # Remove numbers and extra whitespace
      normalized_req = req[:requirement].gsub(/^\d+\.\s+/, '').strip

      # Create a unique key for this requirement
      req_key = "#{normalized_req}|#{req[:conformance]}|#{req[:actor]}"

      # Only add if we haven't seen this requirement before
      unless seen_requirements.include?(req_key)
        seen_requirements.add(req_key)
        unique_requirements << req
      end
    end

    # Write requirements to Excel file
    begin
      create_excel_file(output_path, unique_requirements)
      puts "Requirements extracted to #{output_path}"
    rescue StandardError => e
      puts "Error creating Excel file: #{e.message}"
      exit 1
    end
  end

  # Helper method to extract requirements from text blocks
  def extract_requirements_from_text(text, url, actor, requirements)
    # Look for patterns like "SHALL", "SHOULD", "MAY" followed by requirements
    conformance_patterns = {
      'SHALL' => /\*\*SHALL\*\*|\bSHALL\b/i,
      'SHOULD' => /\*\*SHOULD\*\*|\bSHOULD\b/i,
      'MAY' => /\*\*MAY\*\*|\bMAY\b/i,
      'SHALL NOT' => /\*\*SHALL NOT\*\*|\bSHALL NOT\b/i
    }

    # Process the text to handle specific patterns in the capability statement
    # First, look for sections with conformance statements followed by numbered lists

    # Split the text into paragraphs
    paragraphs = text.split(/\n\n+|\r\n\r\n+/)

    current_conformance = nil

    paragraphs.each do |paragraph|
      # Check if this paragraph contains a conformance statement
      conformance_patterns.each do |level, pattern|
        if paragraph.match?(pattern)
          if paragraph.include?(':') && paragraph.strip.end_with?(':')
            # This is a header with a conformance statement ending with a colon
            # Set the current conformance level for subsequent list items
            current_conformance = level
            break
          elsif paragraph.match?(/\d+\.|-|\*/) && current_conformance
            # This is a list item under a conformance statement
            # Extract the list items
            extract_list_items(paragraph, url, actor, current_conformance, requirements)
          else
            # This is a standalone conformance statement
            # Reset current_conformance after processing
            local_conformance = level
            requirements << {
              url: url,
              requirement: paragraph.strip,
              conformance: local_conformance,
              actor: actor
            }
            current_conformance = nil
          end
        end
      end

      # If this paragraph starts with a number or bullet and we have a current conformance level
      if (paragraph.match?(/^\s*\d+\./) || paragraph.match?(/^\s*[\-\*]/)) && current_conformance
        extract_list_items(paragraph, url, actor, current_conformance, requirements)
      end
    end

    # Now handle the specific case of the documentation section in the capability statement
    # This is a special case for the format used in the example
    if text.include?('The TOC Server **SHALL**:') || text.include?('The TOC Server SHALL:')
      # Extract the SHALL section
      shall_section = text.split(/The TOC Server \*\*SHALL\*\*:|The TOC Server SHALL:/i)[1]
      if shall_section
        shall_section = shall_section.split(/The TOC Server \*\*SHOULD\*\*:|The TOC Server SHOULD:/i)[0]

        # Extract numbered requirements
        shall_requirements = extract_numbered_requirements(shall_section)
        shall_requirements.each do |req|
          requirements << {
            url: url,
            requirement: req.strip,
            conformance: 'SHALL',
            actor: actor
          }
        end
      end

      # Extract the SHOULD section
      if text.include?('The TOC Server **SHOULD**:') || text.include?('The TOC Server SHOULD:')
        should_section = text.split(/The TOC Server \*\*SHOULD\*\*:|The TOC Server SHOULD:/i)[1]
        if should_section
          # Extract numbered requirements
          should_requirements = extract_numbered_requirements(should_section)
          should_requirements.each do |req|
            requirements << {
              url: url,
              requirement: req.strip,
              conformance: 'SHOULD',
              actor: actor
            }
          end
        end
      end
    end

    # Also process security requirements which have a specific format
    return unless text.include?('A server **SHALL**') || text.include?('A server SHALL')

    # Extract security requirements
    security_reqs = text.scan(/A server \*\*SHALL\*\*.*?\.|\bA server SHALL\b.*?\./)
    security_reqs.each do |req|
      requirements << {
        url: url,
        requirement: req.strip,
        conformance: 'SHALL',
        actor: actor
      }
    end
  end

  # Helper method to extract list items from a paragraph
  def extract_list_items(paragraph, url, actor, conformance, requirements)
    # Split by numbered items or bullet points
    items = paragraph.split(/(?=^\s*\d+\.)|(?=^\s*[\-\*])/)

    items.each do |item|
      item = item.strip
      next if item.empty?

      # Remove the number or bullet from the beginning
      item = item.sub(/^\s*\d+\.\s*|\s*[\-\*]\s*/, '')

      # Add as a requirement
      requirements << {
        url: url,
        requirement: item,
        conformance: conformance,
        actor: actor
      }
    end
  end

  # Helper method to extract numbered requirements from a section
  def extract_numbered_requirements(section)
    requirements = []

    # Look for numbered items (1., 2., etc.)
    numbered_items = section.scan(/\d+\.\s+.*?(?=\n\d+\.|\n\n|\z)/m)

    numbered_items.each do |item|
      # Clean up the item
      clean_item = item.strip

      # Handle nested bullet points
      if clean_item.include?('-')
        # Get the main requirement (before any bullet points)
        main_part = clean_item.split(/\n\s*-/)[0].strip
        requirements << main_part unless main_part.empty?

        # Get the bullet points
        bullet_points = clean_item.scan(/\n\s*-\s+(.*?)(?=\n\s*-|\z)/m)
        bullet_points.each do |bullet|
          requirements << bullet[0].strip unless bullet[0].strip.empty?
        end
      else
        requirements << clean_item
      end
    end

    requirements
  end

  # Helper method to create the Excel file
  def create_excel_file(output_path, requirements)
    Axlsx::Package.new do |p|
      p.workbook.add_worksheet(name: 'Requirements') do |sheet|
        # Add header row
        sheet.add_row %w[URL Requirement Conformance Actor]

        # Add data rows
        requirements.each do |req|
          sheet.add_row [req[:url], req[:requirement], req[:conformance], req[:actor]]
        end

        # Apply some basic styling
        sheet.column_widths 40, 60, 15, 15
      end

      p.serialize(output_path)
    end
  end
end
