################################################################################
#
# Composition Model
#
# Copyright (c) 2021 The MITRE Corporation.  All rights reserved.
#
################################################################################

class Composition < Resource
  include ActiveModel::Model
  include ActiveModel::Serializers::JSON

  attr_reader :id, :language, :identifier, :status, :type, :category, :date,
              :author, :title, :custodian, :subject, :section

  #-----------------------------------------------------------------------------

  def initialize(fhir_composition, fhir_bundle)
    @id = fhir_composition.id
    @language = fhir_composition.language
    @identifier = fhir_composition.identifier
    @status = fhir_composition.status
    @type = fhir_composition.type
    @category = fhir_composition.category
    @date = fhir_composition.date
    @author = fhir_composition.author
    @title = fhir_composition.title
    @custodian = fhir_composition.custodian
    @subject = fhir_composition.subject
    @section = fhir_composition.section

    fill_sections(@section, fhir_bundle) unless fhir_bundle.nil?
  end

  #-----------------------------------------------------------------------------
  protected

  #-----------------------------------------------------------------------------

  def fill_sections(section_list, fhir_bundle)
    @section = []

    section_list.each do |section|
      section_objects = {}
      section_objects["text"] = section&.text&.div
      section_objects["title"] = section&.title
      section_objects["objects"] = []
      section.entry&.each do |current_entry|

        #check that current_entry.reference exists and is formatted correctly
        if current_entry.reference.present? && current_entry.reference&.split("/")&.length == 2
          #passed error check. Now get the correct data from bundle
          ref_arr = current_entry.reference&.split("/")
          my_hash = { resource_type: ref_arr.first }
          temp_resource_id = ref_arr.last
          temp_resource = get_object_from_bundle(current_entry, fhir_bundle) || {}

          begin
            case my_hash[:resource_type]
            when "ServiceRequest"
              my_hash[:category] = category_string(temp_resource&.category)
              my_hash[:request] = coding_string(temp_resource&.code&.coding)
              my_hash[:request_text] = temp_resource&.code&.text
              my_hash[:status] = temp_resource.status
            when "Goal"
              my_hash[:type] = temp_resource&.category[1]&.coding&.first&.display
              my_hash[:preference] = temp_resource&.description&.text
            when "Observation"
              my_hash[:type] = coding_string(temp_resource&.code&.coding)
              my_hash[:type_text] = temp_resource&.code&.text
              if temp_resource&.valueCodeableConcept.nil?
                my_hash[:preference] = "placeholder"
                my_hash[:preference_text] = "placeholder"
              else
                my_hash[:preference] = coding_string(temp_resource.valueCodeableConcept&.coding)
                my_hash[:preference_text] = temp_resource&.code&.text
              end
            else
              puts "error unexpected type: #{current_entry.reference.split("/")[1]}"
            end
            section_objects["objects"].push(my_hash)
          rescue => e
            puts "oops #{e.message}"
          end
        end
      end

      @section.push(section_objects)
    end
  end

  #-----------------------------------------------------------------------------

  def get_object_from_bundle(fhir_reference, fhir_bundle)
    ref_arr = fhir_reference.reference&.split("/")
    referenced_object = fhir_bundle.entry.map(&:resource).select do |resource|
      if fhir_reference
        resource.resourceType == ref_arr.first
        # puts resource.resourceType
        resource.id == ref_arr.last
      end
    end
    referenced_object[0]
  end

  #-----------------------------------------------------------------------------

  def category_string(category_list)
    text = []

    category_list&.each do |category|
      text << coding_string(category.coding)
    end

    text.join(", ")
  end

  #-----------------------------------------------------------------------------

  def coding_string(coding_list)
    code = {
      "100826-7" => "Portable medical order &or advance directive review",
      "100827-5" => "Portable medical order discussion participants"
    }
    text = []

    coding_list&.each do |coding|
      display = code[coding.code]
      text << (coding.display || display)
    end

    text.join(", ")
  end
end
