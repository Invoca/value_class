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

    def eql?(other_key)
      self.==(other_key)
    end

    def hash
      [host, username, password, timeout].hash
    end
  end
end
