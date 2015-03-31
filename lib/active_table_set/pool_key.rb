require 'active_table_set/model_comparison'

module ActiveTableSet
  class PoolKey
    include ActiveTableSet::ModelComparison

    attr_accessor :host, :username, :password, :timeout

    def initialize(host: nil, username: nil, password: nil, timeout: nil)
      host     or raise "Must provide a host"
      username or raise "Must provide a username"
      password or raise "Must provide a password"
      timeout  or raise "Must provide a timeout"

      @host     = host
      @username = username
      @password = password
      @timeout  = timeout
    end
  end
end
