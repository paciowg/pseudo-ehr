################################################################################
#
# Patient Model
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class Patient < Resource

	include ActiveModel::Model

  attr_reader :id, :names, :telecoms, :addresses, :birth_date, :gender, 
  								:marital_status, :photo

  #-----------------------------------------------------------------------------

  def initialize(fhir_patient, fhir_client)
    @id               = fhir_patient&.id
  	@names 						= fhir_patient&.name
  	@telecoms 				= fhir_patient&.telecom
  	@addresses 				= fhir_patient&.address
  	@birth_date 			= fhir_patient&.birthDate&.to_date
  	@gender 					= fhir_patient&.gender
  	@marital_status 	= fhir_patient&.maritalStatus
  	@photo						= nil
    @resource_type    = fhir_patient&.resourceType

  	@fhir_client			= fhir_client
  end

  #-----------------------------------------------------------------------------

  def medications
  	medications = []

    search_param = 	{ search: 
    									{ parameters: 
    										{ 
                          patient: ["Patient", @id].join('/') 
    										} 
    									} 
    								}

    fhir_bundle = @fhir_client.search(FHIR::Medication, search_param).resource
    unless fhir_bundle.nil?
      fhir_medications = filter(fhir_bundle.entry.map(&:resource), 'Medication')

      fhir_medications.compact.each do |fhir_medication|
    	  medications << Medication.new(fhir_medication)
      end
    end
    return medications
  end

  #-----------------------------------------------------------------------------

  def medication_statements
    medication_statements = []

    search_param =  { search: 
                      { parameters: 
                        { 
                          subject: ["Patient", @id].join('/') 
                        } 
                      } 
                    }

    fhir_bundle = @fhir_client.search(FHIR::MedicationStatement, search_param).resource
    unless fhir_bundle.nil?
      fhir_medication_statements = filter(fhir_bundle.entry.map(&:resource), 
                                              'MedicationStatement')

      fhir_medication_statements.compact.each do |fhir_medication_statement|
       medication_statements << MedicationStatement.new(fhir_medication_statement, @fhir_client)
     end
    end

    return medication_statements
  end

  #-----------------------------------------------------------------------------

  def compositions
    compositions = []

    search_param =  { search: 
      { parameters: 
        { 
          subject: ["Patient", @id].join('/') 
        } 
      } 
    }

    fhir_bundle = @fhir_client.search(FHIR::Composition, search_param).resource
    unless fhir_bundle.nil?
      fhir_compositions = filter(fhir_bundle.entry&.map(&:resource), 'Composition')

      fhir_compositions&.compact&.each do |composition|
       compositions << Composition.new(composition, fhir_bundle)
     end
    end

    return compositions

  end
  

  #-----------------------------------------------------------------------------

  def encounters
    encounters = []

    search_param =  { search: 
      { parameters: 
        { 
          subject: ["Patient", @id].join('/') 
        } 
      } 
    }
    fhir_bundle = @fhir_client.search(FHIR::Encounter, search_param).resource
    
    unless fhir_bundle.nil?
      fhir_bundle.entry&.each do |entry|
        fhir_encounter = entry.resource
        encounters << Encounter.new(fhir_encounter, @fhir_client)
      end 
     
    end

    return encounters
  end
  
  #-----------------------------------------------------------------------------

  def bundled_functional_statuses
    bundled_functional_statuses = []

    search_param =  { search:
                      { parameters:
                        { 
                          subject: ["Patient", @id].join('/'),
                          _profile: 'http://paciowg.github.io/functional-status-ig/StructureDefinition/pacio-bfs' 
                        }
                      }
                    }

    fhir_bundle = @fhir_client.search(FHIR::Observation, search_param).resource
    unless fhir_bundle.nil?
      fhir_functional_statuses = filter(fhir_bundle.entry.map(&:resource), 'Observation')
    
      fhir_functional_statuses.compact.each do |fhir_functional_status|
      bundled_functional_statuses << BundledFunctionalStatus.new(fhir_functional_status, @fhir_client) 
    end
    end

    return bundled_functional_statuses
  end

  #-----------------------------------------------------------------------------

  def bundled_cognitive_statuses
    bundled_cognitive_statuses = []

    search_param =  { search:
                      { parameters:
                        { 
                          subject: ["Patient", @id].join('/'),
                          _profile: 'http://paciowg.github.io/functional-status-ig/StructureDefinition/pacio-bcs' 
                        }
                      }
                    }

    fhir_bundle = @fhir_client.search(FHIR::Observation, search_param).resource
    unless fhir_bundle.nil?
      fhir_cognitive_statuses = filter(fhir_bundle.entry.map(&:resource), 'Observation')

      fhir_cognitive_statuses.compact.each do |fhir_cognitive_status|
        bundled_cognitive_statuses << BundledCognitiveStatus.new(fhir_cognitive_status, @fhir_client)
      end
    end

    return bundled_cognitive_statuses
  end

  #-----------------------------------------------------------------------------

  def all_functional_statuses
    all_functional_statuses = []

    fhir_functional_statuses = get_fhir_statuses_with_profile(
                        'http://paciowg.github.io/functional-status-ig/StructureDefinition/pacio-bfs')
    fhir_functional_statuses.compact.each do |fhir_functional_status|
      functional_statuses = {}
      functional_statuses[:bundle] = BundledFunctionalStatus.new(fhir_functional_status, @fhir_client)
      functional_statuses[:assessments] = functional_statuses[:bundle].functional_statuses
      all_functional_statuses << functional_statuses
    end

    return all_functional_statuses
  end

  #-----------------------------------------------------------------------------

  def all_cognitive_statuses
    all_cognitive_statuses = []

    fhir_cognitive_statuses = get_fhir_statuses_with_profile(
                        'http://paciowg.github.io/functional-status-ig/StructureDefinition/pacio-bcs')
    fhir_cognitive_statuses.compact.each do |fhir_cognitive_status|
      cognitive_statuses = {}
      cognitive_statuses[:bundle] = BundledCognitiveStatus.new(fhir_cognitive_status, @fhir_client)
      cognitive_statuses[:assessments] = cognitive_statuses[:bundle].cognitive_statuses
      all_cognitive_statuses << cognitive_statuses
    end

    return all_cognitive_statuses
  end

  #-----------------------------------------------------------------------------

  def age
    if @birth_date
      now = Time.now.to_date
      age = now.year - @birth_date.year

      if now.month < @birth_date.month || (now.month == @birth_date.month && now.day < @birth_date.day)
        age -= 1
      end

      return age.to_s
    end
    
  end

  #-----------------------------------------------------------------------------
  private
  #-----------------------------------------------------------------------------

  def filter(fhir_resources, type)
    fhir_resources&.select do |resource| 
    	resource.resourceType == type
    end
  end

  #-----------------------------------------------------------------------------

  def get_fhir_statuses_with_profile(profile)
    search_param =  { search:
                      { parameters:
                        { 
                          subject: ["Patient", @id].join('/'),
                          _profile: profile 
                        }
                      }
                    }

    fhir_bundle = @fhir_client.search(FHIR::Observation, search_param).resource
    fhir_statuses = fhir_bundle&.entry&.map(&:resource)
  end

end
