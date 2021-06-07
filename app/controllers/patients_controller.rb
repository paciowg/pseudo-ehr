class PatientsController < ApplicationController
  # before_action :set_patient, only: [:show, :edit, :update, :destroy]
  before_action :setup_fhir_client

  # GET /patients
  # GET /patients.json
  def index
    if params[:name]
      fhir_response = @fhir_client.search(FHIR::Patient, search: {parameters: {name: params[:name]}})
    else
      fhir_response = @fhir_client.search(FHIR::Patient)
    end
    fhir_bundle = fhir_response.resource
    @patients = fhir_bundle.entry.collect{ |singleEntry| singleEntry.resource }.compact unless fhir_bundle.nil?
    
    # Display the fhir query being run on the UI to help implementers
    @fhir_query = "#{fhir_response.request[:method].capitalize} #{fhir_response.request[:url]}"

    render 'home/index'
  end

  # GET /patients/1
  # GET /patients/1.json
  def show
    redirect_to :controller => 'dashboard', :action => 'index', patient: params[:id]
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
