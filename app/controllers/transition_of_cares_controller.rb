# frozen_string_literal: true

# app/controllers/transition_of_cares_controller.rb
class TransitionOfCaresController < ApplicationController
  before_action :require_server, :retrieve_patient

  # GET /patients/:patient_id/transition_of_cares
  # TODO: read Composition?patient=patient_id&_include=*
  # def index
  #   @adis = fetch_adis(params[:patient_id])
  #   flash.now[:notice] = 'No ADI found' if @adis.empty?
  # rescue StandardError => e
  #   Rails.logger.error e
  #   flash.now[:danger] = e.message
  #   @adis = []
  # end

  # GET /patients/:patient_id/transition_of_cares/:id
  def show
    @toc = fetch_toc(params[:id])
  rescue StandardError => e
    flash[:danger] = e.message
    redirect_to patients_path
  end

  private

  def fetch_toc(toc_id)
    response = @client.read(FHIR::Bundle, toc_id)
    bundle = response.try(:resource)
    request = response.request
    add_query("#{request[:method].upcase} #{request[:url]}")
    raise "Unable to fetch TOC Bundle with id #{toc_id} from FHIR server." if bundle.nil?

    bundle_entries = bundle.entry.map(&:resource)
    composition = bundle_entries.find { |res| res.resourceType == 'Composition' }

    raise "No TOC Composition for patient #{@patient.id}." if composition.nil?

    Composition.new(composition, bundle_entries)
  rescue Net::ReadTimeout, Net::OpenTimeout
    raise "Unable to fetch Bundle/#{toc_id}: Request timed out."
  rescue StandardError => e
    raise e.message
  end
end
