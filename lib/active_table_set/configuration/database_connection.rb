# frozen_string_literal: true

module ActiveTableSet
  module Configuration
    class DatabaseConnection
      include ValueClass::Constructable
      include ValueClass::ThreadLocalAttribute

      value_attr :host
      value_attr :read_write_username
      value_attr :read_write_password
      value_attr :read_only_username
      value_attr :read_only_password
      value_attr :database
      value_attr :connect_timeout
      value_attr :wait_timeout
      value_attr :pool_size
      value_attr :adapter
      value_attr :collation
      value_attr :encoding
      value_attr :reconnect

      thread_local_instance_attr :_previous_host

      DEFAULT = DatabaseConnection.new(
        host:            "localhost",
        connect_timeout: 5,
        wait_timeout:    2147483,
        pool_size:       5,
        adapter:         "mysql2",
        collation:       "utf8_general_ci",
        encoding:        "utf8",
        reconnect:       true
      )

      def pool_key(alternates:, timeout:, access: :leader, context: "")
        PoolKey.new(
          host:            new_value_or_previous(:host, alternates, context),
          database:        find_value(:database, alternates, context),
          username:        find_value(access == :leader ? :read_write_username : :read_only_username, alternates, context),
          password:        find_value(access == :leader ? :read_write_password : :read_only_password, alternates, context),
          connect_timeout: find_value(:connect_timeout, alternates, context),
          wait_timeout:    find_value(:wait_timeout, alternates, context),
          read_timeout:    timeout,
          write_timeout:   timeout,
          encoding:        find_value(:encoding, alternates, context),
          collation:       find_value(:collation, alternates, context),
          adapter:         find_value(:adapter, alternates, context),
          pool:            find_value(:pool_size, alternates, context),
          reconnect:       find_value(:reconnect, alternates, context)
        )
      end

      private

      def new_value_or_previous(name, alternates, context)
        if (value = find_value(name, alternates, context))
          set_previous_value(name, value)
          value
        else
          previous_value(name)
        end
      end

      def find_value(name, alternates, context)
        ([self] + alternates + [DEFAULT]).each do |config|
          unless (v = config.send(name)).nil?
            return call_if_proc(v)
          end
        end

        raise ArgumentError, "could not resolve #{name} value for #{context.inspect}"
      end

      def call_if_proc(value)
        if value.respond_to?(:call)
          nil_on_raise { value.call }
        else
          value
        end
      end

      def previous_value(name)
        send("_previous_#{name}")
      end

      def set_previous_value(name, value)
        send("_previous_#{name}=", value)
      end

      def nil_on_raise
        # rubocop:disable Style/RescueStandardError
        begin
          yield
        rescue => e
          nil
        end
        # rubocop:enable Style/RescueStandardError
      end
    end
  end
end
