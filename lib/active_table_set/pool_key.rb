require 'active_table_set/model_comparison'

module ActiveTableSet
  class PoolKey
    include ActiveTableSet::ModelComparison

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
  end
end
