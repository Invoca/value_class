require 'attr_comparable'

module ActiveTableSet
  class PoolKey
    include AttrComparable

    attr_compare  :host, :username, :password, :timeout
    attr_reader   :host, :username, :password, :timeout
    attr_accessor :config

    def initialize(host:, username:, password:, timeout:, config:)
      @host     = host
      @username = username
      @password = password
      @timeout  = timeout
      @config   = config
    end

    def clone_with_new_timeout(timeout)
      copy = self.clone
      copy.config = self.config.clone
      copy.reset_timeout(timeout)
      copy
    end

    def reset_timeout(timeout)
      @timeout = timeout
      @config.timeout = timeout
    end
  end
end
