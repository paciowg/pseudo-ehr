module ResourcePutHelper
  TIMEOUT_ERROR_MESSAGE = 'Unable to put resources: Request timed out.'.freeze
  
  def current_server
    @current_server ||= FhirServer.find_by(base_url: session[:fhir_server_url])
  end

  def client
    @client ||= FhirClientService.new(fhir_server: current_server).client
  end

  def queries
    session[:queries] ||= []
  end

  def add_query(request)
    return unless request

    queries << "#{request[:method].upcase} #{request[:url]}"
  end

  def create_new_toc_resource(new_resource, method: nil, parameters: {}, id: nil)
    response = case method
               when :put
                 client.update(new_resource, id)
               else
                 raise "Unsupported method: #{method}"
               end

    add_query(response.request)
    success = response.resource.is_a?(FHIR::Bundle) ||
              response.resource.is_a?(FHIR::Composition)
    return response if success
      raise "Error updating or creating #{new_resource.resourceType}:\n #{response.resource&.inspect}"
    rescue Net::ReadTimeout, Net::OpenTimeout
      raise TIMEOUT_ERROR_MESSAGE
  end
end
