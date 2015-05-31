module ActiveTableSet
  # these match the active record connection attributes.
  class PoolKey < ValueClass.struct(
    :host, :database, :username, :password, :connect_timeout, :read_timeout,
    :write_timeout, :encoding, :collation, :adapter, :pool, :reconnect)


    # TODO - need test
    def connector_name
      "#{adapter}_connection"
    end
  end

end

