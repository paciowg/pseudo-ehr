class EpisodeOfCaresController < ApplicationController
  before_action :set_fhir_client

  # GET /episode_of_cares
  # GET /episode_of_cares.json
  def index
    @episode_of_cares = EpisodeOfCare.all
  end

  # GET /episode_of_cares/1
  # GET /episode_of_cares/1.json
  def show
    fhir_response = @fhir_client.read(FHIR::EpisodeOfCare, params[:id])
    @episode_of_care = EpisodeOfCare.new(fhir_response.resource, @fhir_client)
    #To display fhir query
    @fhir_queries = ["#{fhir_response.request[:method].capitalize} #{fhir_response.request[:url]}"] + @episode_of_care.fhir_queries

    @encounters = @episode_of_care.encounters
    @patient = Patient.new(@episode_of_care.patient, @fhir_client)
    fhir_response = @fhir_client.read(nil, @episode_of_care.care_manager.practitioner.reference)
    @fhir_queries << "#{fhir_response.request[:method].capitalize} #{fhir_response.request[:url]}"
    @practitioner = Practitioner.new(fhir_response.resource)
  end

  # GET /episode_of_cares/new
  def new
    @episode_of_care = EpisodeOfCare.new
  end

  # GET /episode_of_cares/1/edit
  def edit
  end

  # POST /episode_of_cares
  # POST /episode_of_cares.json
  def create
    @episode_of_care = EpisodeOfCare.new(episode_of_care_params)

    respond_to do |format|
      if @episode_of_care.save
        format.html { redirect_to @episode_of_care, notice: 'Episode of care was successfully created.' }
        format.json { render :show, status: :created, location: @episode_of_care }
      else
        format.html { render :new }
        format.json { render json: @episode_of_care.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /episode_of_cares/1
  # PATCH/PUT /episode_of_cares/1.json
  def update
    respond_to do |format|
      if @episode_of_care.update(episode_of_care_params)
        format.html { redirect_to @episode_of_care, notice: 'Episode of care was successfully updated.' }
        format.json { render :show, status: :ok, location: @episode_of_care }
      else
        format.html { render :edit }
        format.json { render json: @episode_of_care.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /episode_of_cares/1
  # DELETE /episode_of_cares/1.json
  def destroy
    @episode_of_care.destroy
    respond_to do |format|
      format.html { redirect_to episode_of_cares_url, notice: 'Episode of care was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions. This is repetitive, should be under applicationController
    def set_fhir_client
      @fhir_client = SessionHandler.fhir_client(session.id)
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def episode_of_care_params
      params.fetch(:episode_of_care, {})
    end
end
