class CompositionsController < ApplicationController

  COMPOSITION_TYPES = {
    Goal: ""
  }

  # GET /compositions
  # GET /compositions.json
  def index
    composition_id = params[:composition]
    if composition_id.present?
      redirect_to :action => "show", :id => composition_id
    end
    fhir_client = SessionHandler.fhir_client(session.id)
    fhir_response = fhir_client.read_feed(FHIR::Composition)
    bundle = fhir_response.resource
    @compositions = []
    bundle.entry.each do |entry|
      fhir_composition = entry.resource
      @compositions << Composition.new(fhir_composition, nil)
    end

     # Display the fhir query being run on the UI to help implementers
     @fhir_query = "#{fhir_response.request[:method].capitalize} #{fhir_response.request[:url]}"
  end

  # GET /compositions/1 
  # GET /compositions/1.json
  def show
    fhir_client = SessionHandler.fhir_client(session.id)

    #get patient
    patient_id = params[:id].split('#')[1]
    fhir_patient = fhir_client.read(FHIR::Patient, patient_id) unless patient_id.nil?
    @patient = Patient.new(fhir_patient.resource, fhir_client) unless fhir_patient.nil?

    #used to search for DocumentReference
    search_param =  { search: 
      { parameters: 
        { 
          subject: ["Patient", patient_id].join('/'), 
          type: "#93037-0" #LOINC code for Portable Medical Order (PMO) Form
        }
      } 
    }
    
    #get DocumentReference of type PMO form with subject equal to this patient
    fhir_response = fhir_client.search(FHIR::DocumentReference, search_param)
    fhir_document_reference = fhir_response.resource.entry.first.resource

    #use the PMO document reference to get the list of compositions
    bundle_id = fhir_document_reference.content.first.attachment.url.split('/')[1]
    fhir_response = fhir_client.read(FHIR::Bundle, bundle_id)
    fhir_bundle = fhir_response.resource
    fhir_bundle.entry.each do |current_entry|
      if current_entry.resource.id == params[:id].split('#')[0]
        #fhir_composition = current_entry.resource
        @composition = Composition.new(current_entry.resource, fhir_bundle)
      end
    end

    #@composition = Composition.new(fhir_composition, fhir_bundle) unless fhir_composition.nil?

    

    ##@bundle_objects = bundle.entry.map(&:resource)

    # Display the fhir query being run on the UI to help implementers
    @fhir_query = "#{fhir_response.request[:method].capitalize} #{fhir_response.request[:url]}"
  end

  # GET /compositions/new
  def new
    fhir_client = SessionHandler.fhir_client(session.id)
    file = File.read('app/controllers/careplan1.json')
    fhir_care_plan = JSON.parse(file)
    @care_plan = CarePlan.new(fhir_care_plan, fhir_client)
  end

  # GET /compositions/1/edit
  def edit
  end

  # POST /compositions
  # POST /compositions.json
  def create
    fhir_client = SessionHandler.fhir_client(session.id)
    @care_plan = CarePlan.new(care_plan_params, fhir_client)

    respond_to do |format|
      if @care_plan.save
        format.html { redirect_to @care_plan, notice: 'Care plan was successfully created.' }
        format.json { render :show, status: :created, location: @care_plan }
      else
        format.html { render :new }
        format.json { render json: @care_plan.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /compositions/1
  # PATCH/PUT /compositions/1.json
  def update
    respond_to do |format|
      if @care_plan.update(care_plan_params)
        format.html { redirect_to @care_plan, notice: 'Care plan was successfully updated.' }
        format.json { render :show, status: :ok, location: @care_plan }
      else
        format.html { render :edit }
        format.json { render json: @care_plan.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /compositions/1
  # DELETE /compositions/1.json
  def destroy
    @care_plan.destroy
    respond_to do |format|
      format.html { redirect_to compositions_url, notice: 'Care plan was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_care_plan
      @care_plan = CarePlan.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def care_plan_params
      params.fetch(:care_plan, {})
    end
end