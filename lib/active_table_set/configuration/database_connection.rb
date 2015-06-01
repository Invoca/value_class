module ActiveTableSet
  module Configuration
    class DatabaseConnection
      include ValueClass::Constructable

      value_attr :host
      value_attr :read_write_username
      value_attr :read_write_password
      value_attr :read_only_username
      value_attr :read_only_password
      value_attr :database
      value_attr :connect_timeout
      value_attr :pool_size
      value_attr :adapter
      value_attr :collation
      value_attr :encoding
      value_attr :reconnect

      DEFAULT = DatabaseConnection.new(
          host:            "localhost",
          connect_timeout: 5,
          pool_size:       5,
          adapter:        "mysql2",
          collation:      "utf8_general_ci",
          encoding:       "utf8",
          reconnect:      true
      )

      def pool_key(alternates:, timeout:, access_mode: :write, context: "")
        PoolKey.new(
            host:            find_value(:host, alternates, context),
            database:        find_value(:database, alternates, context),
            username:        find_value(access_mode == :write ? :read_write_username : :read_only_username, alternates, context),
            password:        find_value(access_mode == :write ? :read_write_password : :read_only_password, alternates, context),
            connect_timeout: find_value(:connect_timeout, alternates, context),
            read_timeout:    timeout,
            write_timeout:   timeout,
            encoding:        find_value(:encoding, alternates, context),
            collation:       find_value(:collation, alternates, context),
            adapter:         find_value(:adapter, alternates, context),
            pool:            find_value(:pool_size, alternates, context),
            reconnect:       find_value(:reconnect, alternates, context))
      end

      private
      def find_value(name, alternates, context)
        ([self] + alternates + [DEFAULT] ).each do |config|
          unless (v = config.send(name)).nil?
            return v
          end
        end
        raise ArgumentError, "could not resolve #{name} value for #{context}"
      end

    end
  end
end
