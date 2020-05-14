class PractitionerRolesController < ApplicationController
  # before_action :set_practitioner_role, only: [:show, :edit, :update, :destroy]

  # GET /practitioner_roles
  # GET /practitioner_roles.json
  def index
    @practitioner_roles = PractitionerRole.all
  end

  # GET /practitioner_roles/1
  # GET /practitioner_roles/1.json
  def show
    fhir_client = SessionHandler.fhir_client(session.id)
    fhir_practitionerRole = fhir_client.read(FHIR::PractitionerRole, params[:id]).resource

    @practitioner_role = PractitionerRole.new(fhir_practitionerRole) unless fhir_practitionerRole.nil?
  end

  # GET /practitioner_roles/new
  def new
    @practitioner_role = PractitionerRole.new
  end

  # GET /practitioner_roles/1/edit
  def edit
  end

  # POST /practitioner_roles
  # POST /practitioner_roles.json
  def create
    @practitioner_role = PractitionerRole.new(practitioner_role_params)

    respond_to do |format|
      if @practitioner_role.save
        format.html { redirect_to @practitioner_role, notice: 'Practitioner role was successfully created.' }
        format.json { render :show, status: :created, location: @practitioner_role }
      else
        format.html { render :new }
        format.json { render json: @practitioner_role.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /practitioner_roles/1
  # PATCH/PUT /practitioner_roles/1.json
  def update
    respond_to do |format|
      if @practitioner_role.update(practitioner_role_params)
        format.html { redirect_to @practitioner_role, notice: 'Practitioner role was successfully updated.' }
        format.json { render :show, status: :ok, location: @practitioner_role }
      else
        format.html { render :edit }
        format.json { render json: @practitioner_role.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /practitioner_roles/1
  # DELETE /practitioner_roles/1.json
  def destroy
    @practitioner_role.destroy
    respond_to do |format|
      format.html { redirect_to practitioner_roles_url, notice: 'Practitioner role was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_practitioner_role
      @practitioner_role = PractitionerRole.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def practitioner_role_params
      params.fetch(:practitioner_role, {})
    end
end
