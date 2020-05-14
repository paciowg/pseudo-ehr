class QuestionnaireResponsesController < ApplicationController
  # before_action :set_questionnaire_response, only: [:show, :edit, :update, :destroy]

  # GET /questionnaire_responses
  # GET /questionnaire_responses.json
  def index
    @questionnaire_responses = QuestionnaireResponse.all
  end

  # GET /questionnaire_responses/1
  # GET /questionnaire_responses/1.json
  def show
    fhir_client = SessionHandler.fhir_client(session.id)
    fhir_questionnaire_response = fhir_client.read(FHIR::QuestionnaireResponse, params[:id]).resource
    @questionnaire_response = QuestionnaireResponse.new(fhir_questionnaire_response) unless fhir_questionnaire_response.nil?

    fhir_questionnaire = fhir_client.read(FHIR::Questionnaire, @questionnaire_response.questionnaire.split('/').last).resource
    @questionnaire              = EltssQuestionnaire.new(fhir_questionnaire) unless fhir_questionnaire.nil?
  end

  # GET /questionnaire_responses/new
  def new
    @questionnaire_response = QuestionnaireResponse.new
  end

  # GET /questionnaire_responses/1/edit
  def edit
  end

  # POST /questionnaire_responses
  # POST /questionnaire_responses.json
  def create
    @questionnaire_response = QuestionnaireResponse.new(questionnaire_response_params)

    respond_to do |format|
      if @questionnaire_response.save
        format.html { redirect_to @questionnaire_response, notice: 'Questionnaire response was successfully created.' }
        format.json { render :show, status: :created, location: @questionnaire_response }
      else
        format.html { render :new }
        format.json { render json: @questionnaire_response.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /questionnaire_responses/1
  # PATCH/PUT /questionnaire_responses/1.json
  def update
    respond_to do |format|
      if @questionnaire_response.update(questionnaire_response_params)
        format.html { redirect_to @questionnaire_response, notice: 'Questionnaire response was successfully updated.' }
        format.json { render :show, status: :ok, location: @questionnaire_response }
      else
        format.html { render :edit }
        format.json { render json: @questionnaire_response.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /questionnaire_responses/1
  # DELETE /questionnaire_responses/1.json
  def destroy
    @questionnaire_response.destroy
    respond_to do |format|
      format.html { redirect_to questionnaire_responses_url, notice: 'Questionnaire response was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_questionnaire_response
      @questionnaire_response = QuestionnaireResponse.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def questionnaire_response_params
      params.fetch(:questionnaire_response, {})
    end
end
