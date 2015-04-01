require 'active_table_set/model_comparison'

module ActiveTableSet
  class PoolKey
    include ActiveTableSet::ModelComparison

    attr_accessor :host, :username, :password, :timeout

    def initialize(host:, username:, password:, timeout:)
      @host     = host
      @username = username
      @password = password
      @timeout  = timeout
    end
  end
end
