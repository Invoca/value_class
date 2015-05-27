require 'attr_comparable'
require 'active_support'

module ActiveTableSet
  module Configuration
    class DatabaseConfig
      include ValueClass::Constructable

      value_attr :host,            default: "localhost"
      value_attr :username,        default: ""
      value_attr :password,        default: ""
      value_attr :database,        default: ""
      value_attr :timeout,         default: 2
      value_attr :connect_timeout, default: 5
      value_attr :pool_size,       default: 5
      value_attr :adapter,         default: "mysql2"
      value_attr :collation,       default: "utf8_general_ci"
      value_attr :encoding,        default: "utf8"
      value_attr :reconnect,       default: true

      include AttrComparable
      attr_compare  :host, :username, :password, :timeout, :database

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
end
