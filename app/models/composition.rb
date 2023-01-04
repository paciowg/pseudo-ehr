################################################################################
#
# Advanced Directive Composition Model
#
# Copyright (c) 2021 The MITRE Corporation.  All rights reserved.
#
################################################################################

class Composition < Resource

  include ActiveModel::Model

  attr_reader :id, :language, :identifier, :status, :type, :category, :date, :author, :title, :custodian, :subject, :section

  #-----------------------------------------------------------------------------

	def initialize(fhir_composition, fhir_bundle)
		@id 									= fhir_composition.id
    @language							= fhir_composition.language
    @identifier           = fhir_composition.identifier
    @status 							= fhir_composition.status
    @type                 = fhir_composition.type
    @category             = fhir_composition.category
    @date                 = fhir_composition.date
    @author               = fhir_composition.author
    @title                = fhir_composition.title
    @custodian            = fhir_composition.custodian
    @subject              = fhir_composition.subject
    @section              = fhir_composition.section
    unless fhir_bundle.nil?
       @subject = get_object_from_bundle(fhir_composition.subject, fhir_bundle)
       fill_sections(fhir_composition.section, fhir_bundle)
    end
  end
  
  def fill_sections(section_list, fhir_bundle)
    @section = []
    section_list.each do |section| 
      section_objects = {}
      section_objects["text"] = section.text.div
      section_objects["title"] = section.title
      section_objects["objects"] = []
      section.entry.each do |current_entry|
        #if current_entry.reference.split('/')[0] == "Consent"
        #end

        # temp_entry = fhir_bundle.entry.select {|e| (e.resource.id  == current_entry.reference.split('/')[1])} 
        # unless temp_entry[0].nil?
        #   section_objects["objects"].push(temp_entry[0].resource.id)
        # end

        section_objects["objects"].push("asdf")


      end
      @section.push(section_objects)
    end
  end



  def get_object_from_bundle(fhir_reference, fhir_bundle)
    referenced_object = fhir_bundle.entry.map(&:resource).select do |resource| 
      if fhir_reference
        resource.resourceType == fhir_reference.reference.split('/')[0]
        # puts resource.resourceType
        resource.id == fhir_reference.reference.split('/')[1]
      end
      
    end
    referenced_object[0]
  end

end
