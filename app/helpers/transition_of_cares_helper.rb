module TransitionOfCaresHelper
  # Get cached resources by type
  def cached_resources_for_select(resource_type)
    controller.cached_resources_type(resource_type)
  end

  # Filter document references by category
  def filter_doc_refs_by_category(resources, category_codes)
    controller.filter_doc_refs_or_compositions_by_category(resources, category_codes)
  end

  # Get ADI category codes
  delegate :adi_category_codes, to: :controller
end
