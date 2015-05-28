# TODO - deprecate

module ActiveTableSet
  # Override this class with your own in config/initializers
  class DefaultConfigLoader
    include ActiveTableSet::ConfigHelpers

    def ats_configuration
      ats_config_file = "#{File.dirname(__FILE__)}/../../config/active_table_set.yml"
      @ats_config ||= load_yaml_config(ats_config_file)
    end

    def ar_configuration
      lead = ats_configuration[:table_sets][:common][:partitions][0][:leader]
      { ats_env => db_cfg(host:     lead[:host],
                          username: lead[:username],
                          password: lead[:password],
                          name:     lead[:database],
                          timeout:  lead[:timeout]) }.with_indifferent_access
    end

    def ats_env
      # override me with, for instance Rails.env
      "test"
    end
  end
end
