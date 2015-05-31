module ActiveTableSet
  # these match the active record connection attributes.
  PoolKey = ValueClass.struct(
    :host,
    :database,
    :username,
    :password,
    :connect_timeout,
    :read_timeout,
    :write_timeout,
    :encoding,
    :collation,
    :adapter,
    :pool,
    :reconnect)
end

