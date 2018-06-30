module ActiveTableSet
  # these match the active record connection attributes.
  class PoolKey < ValueClass.struct(
    :host, :database, :username, :password, :connect_timeout, :read_timeout,
    :write_timeout, :encoding, :collation, :adapter, :pool, :reconnect)

    def connector_name
      "#{adapter}_connection"
    end

    def connection_spec(table_set)
      spec_class =
          if defined?(ActiveRecord::ConnectionAdapters::ConnectionSpecification)
            ActiveRecord::ConnectionAdapters::ConnectionSpecification
          else
            ActiveRecord::Base::ConnectionSpecification
          end
      spec_class.new(to_hash, connector_name).tap do |cs|
        cs.config["table_set"] = table_set
      end
    end
  end
end
