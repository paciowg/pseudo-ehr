class ObservationEltssesController < ApplicationController
  before_action :set_observation_eltss, only: [:show, :edit, :update, :destroy]

  # GET /observation_eltsses
  # GET /observation_eltsses.json
  def index
    @observation_eltsses = ObservationEltss.all
  end

  # GET /observation_eltsses/1
  # GET /observation_eltsses/1.json
  def show
  end

  # GET /observation_eltsses/new
  def new
    @observation_eltss = ObservationEltss.new
  end

  # GET /observation_eltsses/1/edit
  def edit
  end

  # POST /observation_eltsses
  # POST /observation_eltsses.json
  def create
    @observation_eltss = ObservationEltss.new(observation_eltss_params)

    respond_to do |format|
      if @observation_eltss.save
        format.html { redirect_to @observation_eltss, notice: 'Observation eltss was successfully created.' }
        format.json { render :show, status: :created, location: @observation_eltss }
      else
        format.html { render :new }
        format.json { render json: @observation_eltss.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /observation_eltsses/1
  # PATCH/PUT /observation_eltsses/1.json
  def update
    respond_to do |format|
      if @observation_eltss.update(observation_eltss_params)
        format.html { redirect_to @observation_eltss, notice: 'Observation eltss was successfully updated.' }
        format.json { render :show, status: :ok, location: @observation_eltss }
      else
        format.html { render :edit }
        format.json { render json: @observation_eltss.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /observation_eltsses/1
  # DELETE /observation_eltsses/1.json
  def destroy
    @observation_eltss.destroy
    respond_to do |format|
      format.html { redirect_to observation_eltsses_url, notice: 'Observation eltss was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_observation_eltss
      @observation_eltss = ObservationEltss.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def observation_eltss_params
      params.fetch(:observation_eltss, {})
    end
end
