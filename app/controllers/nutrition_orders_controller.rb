# app/controllers/nutrition_orders_controller.rb
class NutritionOrdersController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/nutrition_orders
  def index
    @pagy, @nutrition_orders = pagy_array(fetch_nutrition_orders(params[:patient_id]), items: 10)
    flash.now[:notice] = I18n.t('controllers.nutrition_orders.no_orders') if @nutrition_orders.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @nutrition_orders = []
  end

  private

  def fetch_nutrition_orders(patient_id)
    nutri_orders = NutritionOrder.filter_by_patient_id(patient_id)
    return sort_orders(nutri_orders) unless NutritionOrder.expired? || nutri_orders.blank?

    entries = retrieve_current_patient_resources
    fhir_nutrition_orders = cached_resources_type('NutritionOrder')

    if fhir_nutrition_orders.blank?
      Rails.logger.info('Nutrition orders not found in patient record cache, fetching directly')
      entries = fetch_nutrition_orders_by_patient(patient_id, 500, NutritionOrder.updated_at)
      fhir_nutrition_orders = entries.select { |entry| entry.resourceType == 'NutritionOrder' }
    end

    entries = (entries + retrieve_other_resources).uniq
    fhir_nutrition_orders.each { |entry| NutritionOrder.new(entry, entries) }

    nutri_orders = NutritionOrder.filter_by_patient_id(patient_id)
    sort_orders(nutri_orders)
  rescue StandardError => e
    Rails.logger.error("Error fetching or parsing Nutrition Orders:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise "Error fetching patient's Nutrition Orders. Check logs for detail."
  end

  def sort_orders(nutri_orders)
    nutri_orders.sort_by { |order| DateTime.parse(order.date) || '' }.reverse
  end
end
