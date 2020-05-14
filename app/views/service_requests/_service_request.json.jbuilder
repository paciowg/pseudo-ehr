json.extract! service_request, :id, :created_at, :updated_at
json.url service_request_url(service_request, format: :json)
