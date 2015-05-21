require 'active_support'

module ActiveTableSet
  class DatabaseConfig

    attr_accessor :host, :username, :password, :database, :timeout, :connect_timeout, :pool_size, :adapter, :collation, :encoding, :reconnect

    def initialize(database: "", connect_timeout: 5, timeout: 2, encoding: "utf8", collation: "utf8_general_ci", adapter: "mysql2", pool_size: 5, host: "localhost", username: "", password: "", reconnect: true)
      @database        = database
      @connect_timeout = connect_timeout
      @timeout         = timeout
      @encoding        = encoding
      @collation       = collation
      @pool_size       = pool_size
      @adapter         = adapter
      @host            = host
      @username        = username
      @password        = password
      @reconnect       = reconnect
    end

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

    def pool_key
      ActiveTableSet::PoolKey.new(host: host, username: username, password: password, timeout: timeout, config: self)
    end
  end
end
