module FHIR
  class Client
    # Override fetch_patient_record to accept search parameters
    def fetch_patient_record(id = nil, startTime = nil, endTime = nil, method = 'GET', format = nil, search_params: {}) # rubocop:disable Naming/MethodParameterName,Naming/VariableName
      fetch_record(id, [startTime, endTime], method, versioned_resource_class('Patient'), format, search_params) # rubocop:disable Naming/VariableName
    end

    # Override fetch_record to accept search parameters
    def fetch_record(id = nil, time = [nil, nil], method = 'GET', klass = versioned_resource_class('Patient'),
                     format = nil, search_params = {})
      headers = {}
      headers[:accept] = format.to_s if format
      format ||= @default_format
      headers[:content_type] = format

      options = {
        resource: klass,
        format:,
        operation: { name: :fetch_patient_record, method: }
      }

      options.deep_merge!(id:) unless id.nil?
      options[:operation][:parameters] = {} if options[:operation][:parameters].nil?
      options[:operation][:parameters][:start] = { type: 'Date', value: time.first } unless time.first.nil?
      options[:operation][:parameters][:end] = { type: 'Date', value: time.last } unless time.last.nil?

      # Merge custom search parameters with immutable structure
      search_params.each do |key, value|
        options[:operation][:parameters][key.to_sym] = { type: 'String', value: }
      end

      if options[:operation][:method] == 'GET'
        reply = get resource_url(options), fhir_headers
      else
        # create Parameters body
        if options[:operation] && options[:operation][:parameters]
          p = versioned_resource_class('Parameters').new
          options[:operation][:parameters].each do |key, value|
            parameter = versioned_resource_class('Parameters::Parameter').new.from_hash(name: key.to_s)
            parameter.method("value#{value[:type]}=").call(value[:value])
            p.parameter << parameter
          end
        end
        reply = post resource_url(options), p, fhir_headers(headers)
      end

      reply.resource = parse_reply(versioned_resource_class('Bundle'), format, reply)
      reply.resource_class = options[:resource]
      reply
    end
  end
end
