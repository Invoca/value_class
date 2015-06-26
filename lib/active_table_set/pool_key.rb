module ActiveTableSet
  # these match the active record connection attributes.
  class PoolKey < ValueClass.struct(
    :host, :database, :username, :password, :connect_timeout, :read_timeout,
    :write_timeout, :encoding, :collation, :adapter, :pool, :reconnect)

    def connector_name
      "#{adapter}_connection"
    end

    def connection_spec
      if defined?(ActiveRecord::ConnectionAdapters::ConnectionSpecification)
        spec_class = ActiveRecord::ConnectionAdapters::ConnectionSpecification
      else
        spec_class = ActiveRecord::Base::ConnectionSpecification
      end
      spec_class.new(to_hash, connector_name)
    end
  end
end
