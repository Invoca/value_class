module ActiveTableSet
  class DefaultConfigLoader
    def ats_config_file
      "#{File.dirname(__FILE__)}/../../config/active_table_set.yml"
    end

    def configuration(filename: ats_config_file)
      @config ||= YAML.load_file(filename).with_indifferent_access
    end
  end
end
