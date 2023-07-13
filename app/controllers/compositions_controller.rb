class CompositionsController < ApplicationController
  include CompositionsHelper

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
    fhir_client = SessionHandler.fhir_client(session.id)
    @patient = $patient
    @composition = $advance_directives.find { |composition| composition.id == params[:id] }
    fhir_res = $fhir_res_dict[params[:id]]
    bundle = fhir_res["bundle"]
    doc_ref = fhir_res["doc_ref"]

    begin
      # create new bundle
      new_bundle = bundle.dup
      new_bundle.entry.each do |entry|
        resource = entry.resource
        if resource.resourceType == "ServiceRequest"
          case resource.category&.first&.coding&.first&.display
          when "Additional portable medical orders or instructions"
            resource.code.text = service_request_params["Additional portable medical orders or instructions"]["text"]
          when "Medically assisted nutrition orders"
            code = service_request_params["Medically assisted nutrition orders"]["code"]
            text = service_request_params["Medically assisted nutrition orders"]["text"]
            resource.code = set_service_request_code(loinc_polst_med_assist_nutr_vs, code, text)
          when  "Initial portable medical treatment orders"
            code = service_request_params["Initial portable medical treatment orders"]["code"]
            text = service_request_params["Initial portable medical treatment orders"]["text"]
            resource.code = set_service_request_code(loinc_polst_initial_tx_vs, code, text)
          when "Cardiopulmonary resuscitation orders"
            code = service_request_params["Cardiopulmonary resuscitation orders"]["code"]
            text = service_request_params["Cardiopulmonary resuscitation orders"]["text"]
            resource.code = set_service_request_code(loinc_polst_cpr_vs, code, text)
          end
        elsif resource.resourceType == "Composition"
          resource.date = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S%:z")
          resource.attester.each { |attester| attester.time = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S%:z") }
          resource.section.each do |section|
            if section.title == "ePOLST Portable Medical Orders"
              section_entries = @composition.section.select { |s| s["title"] == section.title }.map { |s| s["objects"] }.flatten
              section_entries.each do |object|
                text = service_request_params[object[:category]]["text"].to_s
                section.text&.div = section.text&.div&.gsub(object[:request_text].to_s, text)
              end
            end
          end
        end
      end

      new_bundle = fhir_client.create(new_bundle).resource
      # create Binary resouce
      fhir_binary = FHIR::Binary.new(
        contentType: "application/fhir+json",
        data: Base64.encode64(new_bundle.to_json)
      )
      fhir_binary = fhir_client.create(fhir_binary).resource
      # create new DocumentReference
      new_doc_ref = doc_ref.dup
      new_doc_ref.status = "current"
      new_doc_ref.relatesTo = set_document_ref_relates_to(doc_ref)
      new_doc_ref.content = set_document_ref_content(fhir_binary.id, new_bundle.id)
      new_doc_ref = fhir_client.create(new_doc_ref)
      # Update the old DocumentReference status to superseded
      doc_ref.status = "superseded"
      fhir_client.update(doc_ref, doc_ref.id)

      flash[:success] = "Successfully updated PMO"
      redirect_to dashboard_path(patient: @patient.id)
    rescue => e
      puts "Error updating PMO: #{e.message}"
      flash[:error] = "An error has occurred while updating the PMO"
      redirect_to composition_path(@composition.id)
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
    # Update service request parameters
    def service_request_params
      params.require(:service_request).permit!
    end

    # Get Loinc code display
    def get_loinc_code_display(loinc_code_list, code)
      loinc_code_list.find { |loinc_code| loinc_code[:code] == code}&.dig(:display)
    end

    # ServiceRequest.code
    def set_service_request_code(loinc_code_list, code, text)
      {
        coding: [
          {
            system: "http://loinc.org",
            code: code,
            display: get_loinc_code_display(loinc_code_list, code)
          }
        ],
        text: text
      }
    end

    # set DocumentReference.relatesTo
    def set_document_ref_relates_to(doc_ref)
      [
        {
          code: "replaces",
          target: {
            reference: "DocumentReference/#{doc_ref.id}"
          }
        }
      ]
    end

    # set DocumentReference.content
    def set_document_ref_content(binary_id, bundle_id)
      [
        {
          attachment: {
            contentType: "application/json",
            url: "Binary/#{binary_id}"
          },
          format: {
            system: "http://ihe.net/fhir/ValueSet/IHE.FormatCode.codesystem",
            code: "urn:hl7-org:sdwg:ccda-on-fhir-json:1.0",
            display: "FHIR Document Bundle"
          }
        },
        {
          attachment: {
            url: "Bundle/#{bundle_id}"
          },
          format: {
            system: "http://ihe.net/fhir/ValueSet/IHE.FormatCode.codesystem",
            code: "urn:hl7-org:sdwg:ccda-on-fhir-json:1.0",
            display: "FHIR Document Bundle"
          }
        }
      ]
    end
end
