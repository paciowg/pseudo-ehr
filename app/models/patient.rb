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
    @id               = fhir_patient.id
  	@names 						= fhir_patient.name
  	@telecoms 				= fhir_patient.telecom
  	@addresses 				= fhir_patient.address
  	@birth_date 			= fhir_patient.birthDate.to_date
  	@gender 					= fhir_patient.gender
  	@marital_status 	= fhir_patient.maritalStatus
  	@photo						= nil
    @resource_type    = fhir_patient.resourceType

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

      fhir_medications.each do |fhir_medication|
      	medications << Medication.new(fhir_medication) unless fhir_medication.nil?
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

      fhir_medication_statements.each do |fhir_medication_statement|
        medication_statements << 
                MedicationStatement.new(fhir_medication_statement, @fhir_client) unless 
                                      fhir_medication_statement.nil?
      end
    end

    return medication_statements
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
      # puts fhir_functional_statuses
      fhir_functional_statuses.each do |fhir_functional_status|
        bundled_functional_statuses << BundledFunctionalStatus.new(fhir_functional_status, @fhir_client) unless 
                                                            fhir_functional_status.nil?
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
                          _profile: 'http://paciowg.github.io/cognitive-status-ig/StructureDefinition/pacio-bcs' 
                        }
                      }
                    }

    fhir_bundle = @fhir_client.search(FHIR::Observation, search_param).resource
    unless fhir_bundle.nil?
      fhir_cognitive_statuses = filter(fhir_bundle.entry.map(&:resource), 'Observation')

      fhir_cognitive_statuses.each do |fhir_cognitive_status|
        bundled_cognitive_statuses << BundledCognitiveStatus.new(fhir_cognitive_status, @fhir_client) unless
                                                              fhir_cognitive_status.nil?
      end
    end

    return bundled_cognitive_statuses
  end

  #-----------------------------------------------------------------------------

  def splasch_collections
    splasch_collections = []

    search_param =  { search:
                      { parameters:
                        { 
                          subject: ["Patient", @id].join('/'),
                          _profile: '???' 
                        }
                      }
                    }

    fhir_bundle = @fhir_client.search(FHIR::Observation, search_param).resource
    unless fhir_bundle.nil?
      fhir_splasch_collections = filter(fhir_bundle.entry.map(&:resource), 'Observation')

      fhir_splasch_collections.each do |fhir_splasch_collection|
        splasch_collections << SplaschCollection.new(fhir_splasch_collection, @fhir_client) unless
                                                              fhir_splasch_collection.nil?
      end
    end

    return splasch_collections
  end

  #-----------------------------------------------------------------------------

  def splasch_observations
    splasch_observations = []

    search_param =  { #search:
                      # { parameters:
                      #   { 
                      #     subject: ["Patient", @id].join('/'),
                      #     _profile: '???' 
                      #   }
                      # }
                    }

    fhir_bundle = @fhir_client.search(FHIR::Observation, search_param).resource
    unless fhir_bundle.nil?
      fhir_splasch_observations = filter(fhir_bundle.entry.map(&:resource), 'Observation')

      fhir_splasch_observations.each do |fhir_splasch_observation|
        splasch_observations << SplaschObservation.new(fhir_splasch_observation) unless
                                                              fhir_splasch_observation.nil?
      end
    end

    return splasch_observations.sort_by(&:effective_datetime).reverse
  end

  #-----------------------------------------------------------------------------

  def spoken_language_comprehension_observations
    spoken_language_comprehension_observations = []

    search_param =  { search:
                      { parameters:
                        { 
                          subject: ["Patient", @id].join('/'),
                          _profile: 'http://paciowg.github.io/splasch-ig/StructureDefinition/splasch-SpokenLanguageComprehensionObservation' 
                        }
                      }
                    }

    fhir_bundle = @fhir_client.search(FHIR::Observation, search_param).resource
    unless fhir_bundle.nil?
      fhir_observations = filter(fhir_bundle.entry.map(&:resource), 'Observation')

      fhir_observations.each do |fhir_observation|
        spoken_language_comprehension_observations << SplaschObservation.new(fhir_observation) unless
                                                              fhir_observation.nil?
      end
    end

    return spoken_language_comprehension_observations
  end

  #-----------------------------------------------------------------------------

  def spoken_language_expression_observations
    spoken_language_expression_observations = []

    search_param =  { search:
                      { parameters:
                        { 
                          subject: ["Patient", @id].join('/'),
                          _profile: 'http://paciowg.github.io/splasch-ig/StructureDefinition/splasch-SpokenLanguageExpressionObservation' 
                        }
                      }
                    }

    fhir_bundle = @fhir_client.search(FHIR::Observation, search_param).resource
    unless fhir_bundle.nil?
      fhir_observations = filter(fhir_bundle.entry.map(&:resource), 'Observation')

      fhir_observations.each do |fhir_observation|
        spoken_language_expression_observations << SplaschObservation.new(fhir_observation) unless
                                                              fhir_observation.nil?
      end
    end

    return spoken_language_expression_observations
  end

  #-----------------------------------------------------------------------------

  def swallowing_observations
    swallowing_observations = []

    search_param =  { search:
                      { parameters:
                        { 
                          subject: ["Patient", @id].join('/'),
                          _profile: 'http://paciowg.github.io/splasch-ig/StructureDefinition/splasch-SwallowingObservation' 
                        }
                      }
                    }

    fhir_bundle = @fhir_client.search(FHIR::Observation, search_param).resource
    unless fhir_bundle.nil?
      fhir_observations = filter(fhir_bundle.entry.map(&:resource), 'Observation')

      fhir_observations.each do |fhir_observation|
        swallowing_observations << SplaschObservation.new(fhir_observation) unless
                                                              fhir_observation.nil?
      end
    end

    return swallowing_observations
  end

  #-----------------------------------------------------------------------------

  def all_functional_statuses
    all_functional_statuses = []

    fhir_functional_statuses = get_fhir_statuses_with_profile(
                        'http://paciowg.github.io/functional-status-ig/StructureDefinition/pacio-bfs')
    fhir_functional_statuses.each do |fhir_functional_status|
      functional_statuses = {}
      functional_statuses[:bundle] = 
                BundledFunctionalStatus.new(fhir_functional_status, @fhir_client) unless 
                                                          fhir_functional_status.nil?
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
    fhir_cognitive_statuses.each do |fhir_cognitive_status|
      cognitive_statuses = {}
      cognitive_statuses[:bundle] =
                BundledCognitiveStatus.new(fhir_cognitive_status, @fhir_client) unless 
                                                          fhir_cognitive_status.nil?
      cognitive_statuses[:assessments] = cognitive_statuses[:bundle].cognitive_statuses
      all_cognitive_statuses << cognitive_statuses
    end

    return all_cognitive_statuses
  end

  #-----------------------------------------------------------------------------

  def all_splasch_collections
    all_splasch_collections = []

    fhir_splasch_collections = get_fhir_statuses_with_profile(
                        'http://paciowg.github.io/functional-status-ig/StructureDefinition/pacio-bcs')
    fhir_splasch_collections.each do |fhir_splasch_collection|
      splasch_collections = {}
      splasch_collections[:bundle] =
                SplaschCollection.new(fhir_splasch_collection, @fhir_client) unless 
                                                          fhir_splasch_collection.nil?
      splasch_collections[:assessments] = splasch_collections[:bundle].splasch_observations
      all_splasch_collections << splasch_collections
    end

    return all_splasch_collections
  end

  #-----------------------------------------------------------------------------

  def age
    now = Time.now.to_date
    age = now.year - @birth_date.year

    if now.month < @birth_date.month || 
                  (now.month == @birth_date.month && now.day < @birth_date.day)
      age -= 1
    end

    age.to_s
  end

  #-----------------------------------------------------------------------------
  private
  #-----------------------------------------------------------------------------

  def filter(fhir_resources, type)
    fhir_resources.select do |resource| 
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
    fhir_statuses = fhir_bundle.entry.map(&:resource)
  end

end
