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
  								:marital_status, :photo, :extension

  attr_accessor :fhir_queries
  #-----------------------------------------------------------------------------

  def initialize(fhir_patient, fhir_client)
    @id               = fhir_patient.id
  	@names 						= fhir_patient.name
  	@telecoms 				= fhir_patient.telecom
  	@addresses 				= fhir_patient.address
    @birth_date = nil
    unless fhir_patient.birthDate.nil?
  	  @birth_date 			= fhir_patient.birthDate.to_date
    end
  	@gender 					= fhir_patient.gender
  	@marital_status 	= fhir_patient.maritalStatus
  	@photo						= nil
    @resource_type    = fhir_patient&.resourceType
    @extension        = fhir_patient.extension

  	@fhir_client			= fhir_client
    @fhir_queries      = []
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

    fhir_response = @fhir_client.search(FHIR::Medication, search_param)
    fhir_bundle = fhir_response.resource
    unless fhir_bundle.nil?
      fhir_medications = filter(fhir_bundle.entry.map(&:resource), 'Medication')

      fhir_medications.compact.each do |fhir_medication|
    	  medications << Medication.new(fhir_medication)
      end
    end

    # @fhir_queries << "#{fhir_response.request[:method].capitalize} #{fhir_response.request[:url]}"
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

    fhir_response = @fhir_client.search(FHIR::MedicationStatement, search_param)
    fhir_bundle = fhir_response.resource
    unless fhir_bundle.nil?
      fhir_medication_statements = filter(fhir_bundle.entry.map(&:resource), 
                                              'MedicationStatement')

      fhir_medication_statements.compact.each do |fhir_medication_statement|
       medication_statements << MedicationStatement.new(fhir_medication_statement, @fhir_client)
     end
    end

    # @fhir_queries << "#{fhir_response.request[:method].capitalize} #{fhir_response.request[:url]}"

    return medication_statements
  end

  #-----------------------------------------------------------------------------

  def document_references
    document_references = []

    search_param =  { search: 
                      { parameters: 
                        { 
                          subject: ["Patient", @id].join('/') 
                        } 
                      } 
                    }

    fhir_response = @fhir_client.search(FHIR::DocumentReference, search_param)
    fhir_bundle = fhir_response.resource

    unless fhir_bundle.nil?
      fhir_document_references = filter(fhir_bundle.entry.map(&:resource), 'DocumentReference')

      fhir_document_references.compact.each do |document_reference|
        document_references << DocumentReference.new(document_reference)
      end
    end

    return document_references
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

    fhir_response = @fhir_client.search(FHIR::Composition, search_param)
    fhir_bundle = fhir_response.resource

    # todo: hard coded ID for bundle
    #fhir_response = @fhir_client.read(FHIR::Bundle, "Example-Smith-Johnson-PMOBundle1")
    #fhir_bundle = fhir_response.resource

    unless fhir_bundle.nil?
      fhir_compositions = filter(fhir_bundle.entry.map(&:resource), 'Composition')

      fhir_compositions.compact.each do |composition|
        compositions << Composition.new(composition, fhir_bundle)
      end
    end

    # @fhir_queries << "#{fhir_response.request[:method].capitalize} #{fhir_response.request[:url]}"

    return compositions

  end
  

  #-----------------------------------------------------------------------------

  def encounters
    encounters = []

    search_param =  { search: 
      { parameters: 
        { 
          subject: ["Patient", @id].join('/'),
          _profile: "http://hl7.org/fhir/us/core/StructureDefinition/us-core-encounter" 
        } 
      } 
    }
    fhir_response = @fhir_client.search(FHIR::Encounter, search_param)
    fhir_bundle = fhir_response.resource
    
    unless fhir_bundle.nil?
      fhir_bundle.entry.each do |entry|
        fhir_encounter = entry.resource
        encounters << Encounter.new(fhir_encounter, @fhir_client)
      end 
     
    end

    @fhir_queries << "#{fhir_response.request[:method].upcase} #{fhir_response.request[:url]}"

    return encounters
  end
  
  #-----------------------------------------------------------------------------

  def advance_directives
    advance_directives = []

    search_param =  { search: 
                      { parameters: 
                        { 
                          subject: ["Patient", @id].join('/'),
                          status: "current" 
                        } 
                      } 
                    }

    # Find all of the document references related to the patient
    fhir_response = @fhir_client.search(FHIR::DocumentReference, search_param)
    fhir_bundle = fhir_response.resource

    unless fhir_bundle.nil?
      fhir_document_references = filter(fhir_bundle.entry.map(&:resource), 'DocumentReference')

      fhir_document_references.compact.each do |document_reference|
        # REVIEW - Ignore document references that don't have a type for now...
        unless document_reference.type.nil?
          document_reference.content.each do |content|
            # REVIEW - Only pay attention to content that is application/json for now...
            if content.attachment.contentType == "application/json"
              id = content.attachment.url.split('/').last
              binary_attachment_bundle = @fhir_client.read(FHIR::Binary, id)
              

              # fhir_attachment_bundle = JSON(Base64.decode64(binary_attachment_bundle.resource.data))
              # fhir_attachment = fhir_attachment_bundle.entries.last
              # fhir_composition = FHIR::Composition.new(fhir_attachment.last.first["resource"])

              fhir_attachment_json = JSON(Base64.decode64(binary_attachment_bundle.resource.data))
              
              fhir_attachment_bundle = FHIR::Bundle.new(fhir_attachment_json)
              
              
              fhir_compositions = filter(fhir_attachment_bundle.entry.map(&:resource), 'Composition')
              fhir_compositions.compact.each do |composition|
                #puts "!!!!!!!!!!!!!! Composition !!!!!!!!!!!!!!!!!"
                #puts composition.to_json
                advance_directives << Composition.new(composition, fhir_attachment_bundle)
              end
              #CAS Put Advance Directives into a global variable
              $advance_directives = advance_directives

              # advance_directives << Composition.new(fhir_composition, fhir_attachment_bundle)
            end
          end
        end
      end
    end

    return advance_directives
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

    fhir_response = @fhir_client.search(FHIR::Observation, search_param)
    fhir_bundle = fhir_response.resource
    unless fhir_bundle.nil?
      fhir_functional_statuses = filter(fhir_bundle.entry.map(&:resource), 'Observation')
    
      fhir_functional_statuses.compact.each do |fhir_functional_status|
        bundled_functional_statuses << BundledFunctionalStatus.new(fhir_functional_status, @fhir_client) 
      end
    end

    # @fhir_queries << "#{fhir_response.request[:method].capitalize} #{fhir_response.request[:url]}"

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

    fhir_response = @fhir_client.search(FHIR::Observation, search_param)
    fhir_bundle = fhir_response.resource
    unless fhir_bundle.nil?
      fhir_cognitive_statuses = filter(fhir_bundle.entry.map(&:resource), 'Observation')

      fhir_cognitive_statuses.compact.each do |fhir_cognitive_status|
        bundled_cognitive_statuses << BundledCognitiveStatus.new(fhir_cognitive_status, @fhir_client)
      end
    end

    # @fhir_queries << "#{fhir_response.request[:method].capitalize} #{fhir_response.request[:url]}"

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

    search_param =  { search:
                      { parameters:
                        { 
                          _count: 200,
                          subject: ["Patient", @id].join('/')
                        }
                      }
                    }

    fhir_bundle = @fhir_client.search(FHIR::Observation, search_param).resource
    unless fhir_bundle.nil?
      fhir_splasch_observations = filter(fhir_bundle.entry.map(&:resource), 'Observation')

      fhir_splasch_observations.each do |fhir_splasch_observation|
        splasch_observations << SplaschObservation.new(fhir_splasch_observation) unless
                                                              fhir_splasch_observation.nil?
      end
    end
    puts splasch_observations
    splasch_observations = splasch_observations.find_all {|splasch_observation| splasch_observation.is_splasch_observation}
    unless splasch_observations.empty?
      return splasch_observations
      # return splasch_observations.sort_by(&:effective_datetime).reverse
    end
    return []
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
    if @birth_date.nil?
      return "unknown"
    end
    now = Time.now.to_date
    age = now.year - @birth_date.year

      if now.month < @birth_date.month || (now.month == @birth_date.month && now.day < @birth_date.day)
        age -= 1
      end

      return age.to_s
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

    fhir_response = @fhir_client.search(FHIR::Observation, search_param)
    fhir_bundle = fhir_response.resource

    # @fhir_queries << "#{fhir_response.request[:method].capitalize} #{fhir_response.request[:url]}"

    fhir_statuses = fhir_bundle&.entry&.map(&:resource)
  end

end
