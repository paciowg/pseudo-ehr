class RelatedPeopleController < ApplicationController
  # before_action :set_related_person, only: [:show, :edit, :update, :destroy]

  # GET /related_people
  # GET /related_people.json
  def index
    @related_people = RelatedPerson.all
  end

  # GET /related_people/1
  # GET /related_people/1.json
  def show
    fhir_client = SessionHandler.fhir_client(session.id)
    fhir_related_person = fhir_client.read(FHIR::RelatedPerson, params[:id]).resource
    @related_person = RelatedPerson.new(fhir_related_person) unless fhir_related_person.nil?

    fhir_patient = fhir_client.read(FHIR::Patient, @related_person.patient.reference.split('/').last).resource
    @patient              = Patient.new(fhir_patient, fhir_client) unless fhir_patient.nil?

  end

  # GET /related_people/new
  def new
    @related_person = RelatedPerson.new
  end

  # GET /related_people/1/edit
  def edit
  end

  # POST /related_people
  # POST /related_people.json
  def create
    @related_person = RelatedPerson.new(related_person_params)

    respond_to do |format|
      if @related_person.save
        format.html { redirect_to @related_person, notice: 'Related person was successfully created.' }
        format.json { render :show, status: :created, location: @related_person }
      else
        format.html { render :new }
        format.json { render json: @related_person.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /related_people/1
  # PATCH/PUT /related_people/1.json
  def update
    respond_to do |format|
      if @related_person.update(related_person_params)
        format.html { redirect_to @related_person, notice: 'Related person was successfully updated.' }
        format.json { render :show, status: :ok, location: @related_person }
      else
        format.html { render :edit }
        format.json { render json: @related_person.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /related_people/1
  # DELETE /related_people/1.json
  def destroy
    @related_person.destroy
    respond_to do |format|
      format.html { redirect_to related_people_url, notice: 'Related person was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_related_person
      @related_person = RelatedPerson.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def related_person_params
      params.fetch(:related_person, {})
    end
end
