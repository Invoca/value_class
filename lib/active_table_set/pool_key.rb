module ActiveTableSet
  class PoolKey
    attr_accessor :ip_address, :username, :password, :timeout

    def initialize(ip_address: nil, username: nil, password: nil, timeout: nil)
      ip_address or raise "Must provide an ip_address"
      username   or raise "Must provide a username"
      password   or raise "Must provide a password"
      timeout    or raise "Must provide a timeout"

      @ip_address = ip_address
      @username   = username
      @password   = password
      @timeout    = timeout
    end

    def ==(other_key)
      @ip_address == other_key.ip_address && @username == other_key.username && @password == other_key.password && @timeout == other_key.timeout
    end
  end
end
