# frozen_string_literal: true

module ActiveTableSet
  # these match the active record connection attributes.
  class PoolKey < ValueClass.struct(
    :host, :database, :username, :password, :connect_timeout, :wait_timeout, :net_read_timeout, :net_write_timeout,
    :read_timeout, :write_timeout, :encoding, :collation, :adapter, :pool, :reconnect, :checkout_timeout)

    def connector_name
      "#{adapter}_connection"
    end

    def connection_spec(table_set)
      ActiveRecord::ConnectionAdapters::ConnectionSpecification.new(to_hash, connector_name).tap do |cs|
        cs.instance_variable_set(:@table_set, table_set)
      end
    end
  end
end
