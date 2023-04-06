class PatientsController < ApplicationController

  before_action :ensure_session_handler
  # before_action :set_patient, only: [:show, :edit, :update, :destroy]
  before_action :setup_fhir_client


  # GET /patients
  # GET /patients?name=   (preform FHIR search with name param)
  # GET /patients?page=   (directly fetch a pagination url from Bundle.link[i].url)
  def index
    if params[:name]
      fhir_response = @fhir_client.search(FHIR::Patient, search: {parameters: {name: params[:name]}})
      fhir_bundle = fhir_response.resource
    elsif params[:page]
      begin
        rest_response = RestClient.get(params[:page]) # TODO: @fhir_client doesn't support pagination, either hack pagination into fhir_client or add oauth2 into RestClient
      rescue RestClient::ExceptionWithResponse => err
        flash[ :alert ] = "RestClient failed to get pagination url #{params[:page]}"
        logger.error "RestClient failed to get pagination url #{params[:page]}"
        logger.error err
        redirect_to root_url
        return
      else
        logger.debug "Restclient successfully recieved pagination url #{params[:page]}"
      end
      fhir_bundle = FHIR.from_contents(rest_response.body)
    else
      fhir_response = @fhir_client.search(FHIR::Patient)
      fhir_bundle = fhir_response.resource
    end
    @patients = fhir_bundle.entry.collect{ |singleEntry| singleEntry.resource }.compact unless fhir_bundle.nil?
    
    # Display the fhir query being run on the UI to help implementers
    if fhir_response
        @fhir_query = "#{fhir_response.request[:method].capitalize} #{fhir_response.request[:url]}"
    else # pagination case
        @fhir_query = "GET #{params[:page]}"
    end

    # Do pagination if bundle supports it
    if fhir_bundle.link
      logger.debug "Parsing bundle pagination!!"
      if fhir_bundle.link.any? { |x| x.relation == "next" }
        @next_url = patients_url + '?page=' + CGI.escape( fhir_bundle.link.select{ |x| x.relation == "next" }.fetch(0).url )
      end
      if fhir_bundle.link.any? { |x| x.relation == "previous" }
        @prev_url = patients_url + '?page=' + CGI.escape( fhir_bundle.link.select{ |x| x.relation == "previous" }.fetch(0).url )
      end
    end

    # renders patient/index instead
    # render 'home/index'
  end

  # GET /patients/pat1
  def show
    # Display the fhir query being run on the UI to help implementers
    # @fhir_queries        = @patient.fhir_queries
    @fhir_queries         = []


    patient_id = params[:id]

    # read patient
    fhir_response        = @fhir_client.read(FHIR::Patient, patient_id)
    @fhir_queries        << "#{fhir_response.request[:method].upcase} #{fhir_response.request[:url]}"
    fhir_patient         = fhir_response.resource
    @patient             = Patient.new(fhir_patient, @fhir_client)

    # $everything patient
    @base_server_url     = SessionHandler.from_storage(session.id, 'connection').base_server_url

    rest_response        = @fhir_client.client.get(File.join(@base_server_url, "Patient/#{patient_id}/$everything"))
    @fhir_queries        << "#{rest_response.request.method.upcase} #{rest_response.request.url}"
    everything_bundle    = FHIR.from_contents( rest_response.body )
    
    @questionnaire_responses = []
    @encounters              = []
    @specimens               = []
    # @care_plans              = []
    @conditions              = []
    @locations               = []
    

    everything_bundle.entry.each do |entry|
      case entry.resource.resourceType.to_s
      when "QuestionnaireResponse"
        @questionnaire_responses << entry.resource
      when "Specimen"
        @specimens << entry.resource
      when "Encounter"
        @encounters << entry.resource
      when "Condition"
        @conditions << entry.resource
      when "Location"
        @locations << entry.resource
      end
    end
    
  end

  # GET /patients/new
  def new
    @patient = Patient.new
  end

  # GET /patients/1/edit
  def edit
  end

  # POST /patients
  # POST /patients.json
  def create
    @patient = Patient.new(patient_params)

    respond_to do |format|
      if @patient.save
        format.html { redirect_to @patient, notice: 'Patient was successfully created.' }
        format.json { render :show, status: :created, location: @patient }
      else
        format.html { render :new }
        format.json { render json: @patient.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /patients/1
  # PATCH/PUT /patients/1.json
  def update
    respond_to do |format|
      if @patient.update(patient_params)
        format.html { redirect_to @patient, notice: 'Patient was successfully updated.' }
        format.json { render :show, status: :ok, location: @patient }
      else
        format.html { render :edit }
        format.json { render json: @patient.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /patients/1
  # DELETE /patients/1.json
  def destroy
    @patient.destroy
    respond_to do |format|
      format.html { redirect_to patients_url, notice: 'Patient was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_patient
      @patient = Patient.find(params[:id])
    end

    def setup_fhir_client
      @fhir_client ||= SessionHandler.fhir_client(session.id)
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def patient_params
      params.fetch(:patient, {})
    end
end
