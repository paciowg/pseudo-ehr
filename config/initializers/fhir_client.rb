module FHIR
  class Client
    unless method_defined?(:parse_reply_without_blank_extension_url_sanitizer)
      alias_method :parse_reply_without_blank_extension_url_sanitizer, :parse_reply

      def parse_reply(klass, format, response)
        sanitize_fhir_reply!(response, format)
        parse_reply_without_blank_extension_url_sanitizer(klass, format, response)
      end
    end

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

    private

    def sanitize_fhir_reply!(reply, format)
      sanitized_body = sanitize_fhir_response_body(reply.body, format)
      reply.response[:body] = sanitized_body if sanitized_body
    end

    def sanitize_fhir_response_body(body, format)
      return body unless json_format?(format) && body.present?

      resource = JSON.parse(body)
      removed_count = remove_blank_extension_urls!(resource)

      if removed_count.positive?
        Rails.logger.warn("Removed #{removed_count} FHIR extension(s) with blank url before parsing response")
        JSON.generate(resource)
      else
        body
      end
    rescue JSON::ParserError
      body
    end

    def json_format?(format)
      format.to_s.include?('json')
    end

    def remove_blank_extension_urls!(value)
      case value
      when Array
        value.sum { |item| remove_blank_extension_urls!(item) }
      when Hash
        removed_count = 0

        %w[extension modifierExtension].each do |extension_key|
          next unless value[extension_key].is_a?(Array)

          value[extension_key].each { |extension| removed_count += remove_blank_extension_urls!(extension) }
          original_size = value[extension_key].size
          value[extension_key].reject! { |extension| extension.is_a?(Hash) && blank_extension_url?(extension['url']) }
          removed_count += original_size - value[extension_key].size
        end

        value.each_value { |child| removed_count += remove_blank_extension_urls!(child) }
        removed_count
      else
        0
      end
    end

    def blank_extension_url?(url)
      url.nil? || url.to_s.strip.empty?
    end
  end
end
