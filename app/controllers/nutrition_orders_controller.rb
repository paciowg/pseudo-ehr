# app/controllers/nutrition_orders_controller.rb
class NutritionOrdersController < ApplicationController
  before_action :require_server, :retrieve_patient

  # GET /patients/:patient_id/nutrition_orders
  def index
    @pagy, @nutrition_orders = pagy_array(fetch_and_cache_nutrition_orders(params[:patient_id]),
                                                 items: 10)
    flash.now[:notice] = 'Patient has no Nutrition Order yet' if @nutrition_orders.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @nutrition_orders = []
  end

  private

  def fetch_and_cache_nutrition_orders(patient_id)
    Rails.cache.fetch(cache_key_for_patient_nutrition_orders(patient_id), expires_in: 1.minute) do
      response = fetch_nutrition_orders_by_patient(patient_id)
      entries = response.resource.entry.map(&:resource)
      fhir_nutrition_orders = entries.select { |entry| entry.resourceType == 'NutritionOrder' }

      fhir_nutrition_orders.map { |entry| NutritionOrder.new(entry, entries) }.sort_by(&:date).reverse
    rescue StandardError => e
      raise "
            Error fetching patient's (#{patient_id}) Nutrition Orders from FHIR server. Status code: #{e.message}
      "
    end
  end

  def fetch_nutrition_orders_by_patient(patient_id)
    search_param = { parameters: {
      patient: patient_id,
      _include: '*'
    } }
    response = @client.search(FHIR::NutritionOrder, search: search_param)
    raise response&.response&.dig(:code) if response&.resource&.entry.nil?

    response
  end

  def cache_key_for_patient_nutrition_orders(patient_id)
    "patient_#{patient_id}_nutrition_orders_#{session_id}"
  end
end
