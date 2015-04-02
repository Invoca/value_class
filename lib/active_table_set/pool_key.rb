require 'attr_comparable'

module ActiveTableSet
  class PoolKey
    include AttrComparable

    attr_compare :host, :username, :password, :timeout
    attr_reader  :host, :username, :password, :timeout

    def initialize(host:, username:, password:, timeout:)
      @host     = host
      @username = username
      @password = password
      @timeout  = timeout
    end
  end
end
