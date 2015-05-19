module ActiveTableSet
  class DefaultConfigLoader
    # override me
    def ats_configuration
      ats_config_file = "#{File.dirname(__FILE__)}/../../config/active_table_set.yml"
      @ats_config ||= YAML.load_file(ats_config_file).with_indifferent_access
    end

    # override me
    def ar_configuration
      lead = ats_configuration[:table_sets][:common][:partitions][0][:leader]
      { ats_env => db_cfg(host:     lead[:host],
                          username: lead[:username],
                          password: lead[:password],
                          name:     lead[:database],
                          timeout:  lead[:timeout]) }.with_indifferent_access
    end

    # override me with, for instance Rails.env
    def ats_env
      "test"
    end

    private

    def load_yaml_config(filename)
      YAML::load(ERB.new(File.read(filename)).result).with_indifferent_access
    end

    def local
      "localhost"
    end

    def db_cfg(host:, username:, password:, name:, timeout: 110, encoding: "utf8", collation: "utf_general_ci", adapter: "mysql2", pool: 5, reconnect: true)
      {
        host:      host,
        database:  name,
        username:  username,
        password:  password,
        timeout:   timeout,
        encoding:  encoding,
        collation: collation,
        adapter:   adapter,
        pool:      pool,
        reconnect: reconnect
      }
    end
  end
end
