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

    #@compositions = $advance_directives

     # Display the fhir query being run on the UI to help implementers
     @fhir_query = "#{fhir_response.request[:method].capitalize} #{fhir_response.request[:url]}"
  end

  # GET /compositions/1
  # GET /compositions/1.json
  def show

    fhir_client = SessionHandler.fhir_client(session.id)
    #CAS Remove query for Composition and use the one loaded into the global done in patient.rb
    #fhir_binary = fhir_client.read(FHIR::Binary, params[:id]).resource

    #fhir_attachment_json = JSON(Base64.decode64(binary_attachment_bundle.resource.data))
    #fhir_attachment_bundle = FHIR::Bundle.new(fhir_attachment_json)
    #fhir_compositions = filter(fhir_attachment_bundle.entry.map(&:resource), 'Composition')
    #fhir_compositions.compact.each do |composition|
    #  advance_directives << Composition.new(composition, fhir_attachment_bundle)
    #end
    @patient = $patient
    # advance_directives = $advance_directives
    @compositions = $advance_directives
    @composition = @compositions.find { |composition| composition.id == params[:id] }
    if @composition.nil?
      flash[:error] = "Composition/ADI not found"
      redirect_to dashboard_path(patient: @patient.id)
    end
    # #todo: replace hard coded string
    # #fhir_response = fhir_client.read(FHIR::Bundle, "Example-Smith-Johnson-PMOBundle1")
    # fhir_response = fhir_client.read(FHIR::Binary, "26819")
    # fhir_binary = fhir_response.resource
    # #Rails.cache.write("$document_bundle", bundle.to_json,  { expires_in: 30.minutes })

    # @composition = Composition.new(fhir_composition, fhir_bundle) unless fhir_composition.nil?

    # fhir_patient = fhir_client.read(FHIR::Patient, "Example-Smith-Johnson-Patient1")
    # @patient = Patient.new(fhir_patient.resource, @fhir_client) unless fhir_patient.nil?
    #CAS Load patient from global patient
    # @patient = $patient
    # ##@bundle_objects = bundle.entry.map(&:resource)

    # Display the fhir query being run on the UI to help implementers
    #CAS query was already done in the patient controller
    #@fhir_query = "#{fhir_response.request[:method].capitalize} #{fhir_response.request[:url]}"
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
