require 'attr_comparable'
require 'active_support'

module ActiveTableSet
  class DatabaseConfig
    include ValueClass::Constructable

    config_attribute :host,            default: "localhost"
    config_attribute :username,        default: ""
    config_attribute :password,        default: ""
    config_attribute :database,        default: ""
    config_attribute :timeout,         default: 2
    config_attribute :connect_timeout, default: 5
    config_attribute :pool_size,       default: 5
    config_attribute :adapter,         default: "mysql2"
    config_attribute :collation,       default: "utf8_general_ci"
    config_attribute :encoding,        default: "utf8"
    config_attribute :reconnect,       default: true

    include AttrComparable
    attr_compare  :host, :username, :password, :timeout

    def specification
      ActiveSupport::HashWithIndifferentAccess.new(
        "database"        => database,
        "connect_timeout" => connect_timeout,
        "read_timeout"    => timeout,
        "write_timeout"   => timeout,
        "encoding"        => encoding,
        "collation"       => collation,
        "adapter"         => adapter,
        "pool"            => pool_size,
        "reconnect"       => reconnect,
        "host"            => host,
        "username"        => username,
        "password"        => password
      )
    end

    def name
      "#{adapter}_connection"
    end

    def clone_with_new_timeout(timeout)
      clone_config { |db_config| db_config.timeout = timeout }
    end

    def eql?(other)
      self == other
    end

    def hash
      [host, username, password, timeout].hash
    end

  end
end
