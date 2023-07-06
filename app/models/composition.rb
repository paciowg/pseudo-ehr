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
    @subject = fhir_composition.subject

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
      section.entry.each do |current_entry|

        #check that current_entry.reference exists and is formatted correctly
        if current_entry.reference.nil?
          puts "error: current_entry.reference is nil"
        elsif (current_entry.reference.split("/")[0]).nil?
          puts "error: current_entry.reference.split('/')[0] is nil"
        elsif (current_entry.reference.split("/")[1]).nil?
          puts "error: current_entry.reference.split('/')[1] is nil"
        else
          #passed error check. Now get the correct data from bundle
          my_hash = { resource_type: current_entry.reference.split("/")[0] }
          temp_resource_id = current_entry.reference.split("/")[1]
          temp_resource = {}

          fhir_bundle.entry.each do |temp_bundle_entry|
            if temp_bundle_entry.resource.id == temp_resource_id
              temp_resource = temp_bundle_entry
            end
          end

          begin
            case my_hash[:resource_type]
            when "ServiceRequest"
              my_hash[:category] = category_string(temp_resource.resource.category)
              my_hash[:request] = coding_string(temp_resource.resource.code.coding)
              my_hash[:request_text] = temp_resource.resource.code.text
              my_hash[:status] = temp_resource.resource.status
            when "Goal"
              my_hash[:type] = temp_resource.resource.category[1].coding[0].display
              my_hash[:preference] = temp_resource.resource.description.text
            when "Observation"
              my_hash[:type] = coding_string(temp_resource.resource.code.coding)
              my_hash[:type_text] = temp_resource.resource.code.text
              if temp_resource.resource.valueCodeableConcept.nil?
                my_hash[:preference] = "placeholder"
                my_hash[:preference_text] = "placeholder"
              else
                my_hash[:preference] = coding_string(temp_resource.resource.valueCodeableConcept.coding)
                my_hash[:preference_text] = temp_resource.resource.code.text
              end
            else
              puts "error unexpected type: #{current_entry.reference.split("/")[1]}"
            end
            section_objects["objects"].push(my_hash)
          rescue
            puts "oops"
          end
        end

        # if (fhir_bundle.entry.select {|e| (e.resource.id  == current_entry.reference.split('/')[1])})[0].nil?
        #   section_objects["objects"].push("qwerty")
        # else
        #   section_objects["objects"].push((fhir_bundle.entry.select {|e| (e.resource.id  == current_entry.reference.split('/')[1])})[0])
        # end

        # section_objects["objects"].push("asdf")
      end

      @section.push(section_objects)
    end
  end

  #-----------------------------------------------------------------------------

  def get_object_from_bundle(fhir_reference, fhir_bundle)
    referenced_object = fhir_bundle.entry.map(&:resource).select do |resource|
      if fhir_reference
        resource.resourceType == fhir_reference.reference.split("/")[0]
        # puts resource.resourceType
        resource.id == fhir_reference.reference.split("/")[1]
      end
    end
    referenced_object[0]
  end

  #-----------------------------------------------------------------------------

  def category_string(category_list)
    text = []

    category_list.each do |category|
      text << coding_string(category.coding)
    end

    text.join(", ")
  end

  #-----------------------------------------------------------------------------

  def coding_string(coding_list)
    text = []

    coding_list.each do |coding|
      text << coding.display
    end

    text.join(", ")
  end
end
