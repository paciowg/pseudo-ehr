# app/controllers/nutrition_orders_controller.rb
class NutritionOrdersController < ApplicationController
  before_action :require_server, :retrieve_patient

  # GET /patients/:patient_id/nutrition_orders
  def index
    @pagy, @nutrition_orders = pagy_array(fetch_and_cache_nutrition_orders(params[:patient_id]), items: 10)
    flash.now[:notice] = 'Patient has no Nutrition Order yet' if @nutrition_orders.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @nutrition_orders = []
  end

  private

  def fetch_and_cache_nutrition_orders(patient_id)
    Rails.cache.fetch(cache_key_for_patient_nutrition_orders(patient_id)) do
      entries = retrieve_current_patient_resources
      fhir_nutrition_orders = cached_resources_type('NutritionOrder')

      if fhir_nutrition_orders.blank?
        entries = fetch_nutrition_orders_by_patient(patient_id)
        fhir_nutrition_orders = entries.select { |entry| entry.resourceType == 'NutritionOrder' }
      end

      entries = (entries + retrieve_practitioner_roles_and_orgs).uniq
      fhir_nutrition_orders.map { |entry| NutritionOrder.new(entry, entries) }
    rescue StandardError => e
      Rails.logger.error("Error fetching or parsing Nutrition Orders:\n #{e.message.inspect}")
      raise "Error fetching patient's Nutrition Orders. Check logs for detail."
    end
  end
end
