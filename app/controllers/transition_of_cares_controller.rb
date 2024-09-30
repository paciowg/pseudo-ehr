# app/controllers/transition_of_cares_controller.rb
class TransitionOfCaresController < ApplicationController
  before_action :require_server, :retrieve_patient

  # GET /patients/:patient_id/transition_of_care
  def show
    @toc = fetch_toc
  rescue StandardError => e
    flash[:danger] = e.message
    redirect_to patients_path
  end

  private

  def fetch_toc
    Rails.cache.fetch(cache_key_for_patient_tocs(params[:patient_id]), expires_in: 1.day) do
      search_param = { parameters: {
        patient: @patient.id,
        type: '81218-0',
        _include: '*'
      }.compact }
      response = @client.search(FHIR::Composition, search: search_param)
      bundle = response.try(:resource)
      request = response.request
      add_query("#{request[:method].upcase} #{request[:url]}")
      raise "Unable to fetch TOC Composition for patient #{@patient.id} from FHIR server." if bundle.nil?

      bundle_entries = bundle.entry.map(&:resource)
      composition = bundle_entries.find { |res| res.resourceType == 'Composition' }

      raise "No TOC Composition for patient #{@patient.id}." if composition.nil?

      Composition.new(composition, bundle_entries)
    rescue Net::ReadTimeout, Net::OpenTimeout
      raise "Unable to fetch patient #{@patient.id} composition: Request timed out."
    rescue StandardError => e
      raise e.message
    end
  end
end
