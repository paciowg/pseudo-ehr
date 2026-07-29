class ObservationConfig
  class << self
    def for_code(code)
      load_config[code.to_s]
    end

    def range_for(code)
      for_code(code)&.dig(:range)
    end

    def cut_points_for(code)
      for_code(code)&.dig(:cut_points) || []
    end

    private

    def load_config
      raw_config = YAML.load_file(config_path) || {}
      raw_config.with_indifferent_access
    end

    def config_path
      Rails.root.join('config/observation_config.yml')
    end
  end
end
