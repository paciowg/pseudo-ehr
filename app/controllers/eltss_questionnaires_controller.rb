class EltssQuestionnairesController < ApplicationController
  before_action :set_eltss_questionnaire, only: [:show, :edit, :update, :destroy]

  # GET /eltss_questionnaires
  # GET /eltss_questionnaires.json
  def index
    @eltss_questionnaires = EltssQuestionnaire.all
  end

  # GET /eltss_questionnaires/1
  # GET /eltss_questionnaires/1.json
  def show
  end

  # GET /eltss_questionnaires/new
  def new
    @eltss_questionnaire = EltssQuestionnaire.new
  end

  # GET /eltss_questionnaires/1/edit
  def edit
  end

  # POST /eltss_questionnaires
  # POST /eltss_questionnaires.json
  def create
    @eltss_questionnaire = EltssQuestionnaire.new(eltss_questionnaire_params)

    respond_to do |format|
      if @eltss_questionnaire.save
        format.html { redirect_to @eltss_questionnaire, notice: 'Eltss questionnaire was successfully created.' }
        format.json { render :show, status: :created, location: @eltss_questionnaire }
      else
        format.html { render :new }
        format.json { render json: @eltss_questionnaire.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /eltss_questionnaires/1
  # PATCH/PUT /eltss_questionnaires/1.json
  def update
    respond_to do |format|
      if @eltss_questionnaire.update(eltss_questionnaire_params)
        format.html { redirect_to @eltss_questionnaire, notice: 'Eltss questionnaire was successfully updated.' }
        format.json { render :show, status: :ok, location: @eltss_questionnaire }
      else
        format.html { render :edit }
        format.json { render json: @eltss_questionnaire.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /eltss_questionnaires/1
  # DELETE /eltss_questionnaires/1.json
  def destroy
    @eltss_questionnaire.destroy
    respond_to do |format|
      format.html { redirect_to eltss_questionnaires_url, notice: 'Eltss questionnaire was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_eltss_questionnaire
      @eltss_questionnaire = EltssQuestionnaire.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def eltss_questionnaire_params
      params.fetch(:eltss_questionnaire, {})
    end
end
