class RiskAssessmentsController < ApplicationController
  before_action :set_risk_assessment, only: [:show, :edit, :update, :destroy]

  # GET /risk_assessments
  # GET /risk_assessments.json
  def index
    @risk_assessments = RiskAssessment.all
  end

  # GET /risk_assessments/1
  # GET /risk_assessments/1.json
  def show
  end

  # GET /risk_assessments/new
  def new
    @risk_assessment = RiskAssessment.new
  end

  # GET /risk_assessments/1/edit
  def edit
  end

  # POST /risk_assessments
  # POST /risk_assessments.json
  def create
    @risk_assessment = RiskAssessment.new(risk_assessment_params)

    respond_to do |format|
      if @risk_assessment.save
        format.html { redirect_to @risk_assessment, notice: 'Risk assessment was successfully created.' }
        format.json { render :show, status: :created, location: @risk_assessment }
      else
        format.html { render :new }
        format.json { render json: @risk_assessment.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /risk_assessments/1
  # PATCH/PUT /risk_assessments/1.json
  def update
    respond_to do |format|
      if @risk_assessment.update(risk_assessment_params)
        format.html { redirect_to @risk_assessment, notice: 'Risk assessment was successfully updated.' }
        format.json { render :show, status: :ok, location: @risk_assessment }
      else
        format.html { render :edit }
        format.json { render json: @risk_assessment.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /risk_assessments/1
  # DELETE /risk_assessments/1.json
  def destroy
    @risk_assessment.destroy
    respond_to do |format|
      format.html { redirect_to risk_assessments_url, notice: 'Risk assessment was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_risk_assessment
      @risk_assessment = RiskAssessment.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def risk_assessment_params
      params.fetch(:risk_assessment, {})
    end
end
