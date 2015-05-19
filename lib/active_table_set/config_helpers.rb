module ActiveTableSet
  module ConfigHelpers
    def load_yaml_config(filename)
      YAML::load(ERB.new(File.read(filename)).result).with_indifferent_access
    end

    def local
      "localhost"
    end

    def db_cfg(host:, username:, password:, name:, timeout: 110, encoding: "utf8", collation: "utf8_general_ci", adapter: "mysql2", pool: 5, reconnect: true)
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
