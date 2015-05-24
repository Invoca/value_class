require 'attr_comparable'

# TODO - this class is almost exactly database config.   Can we merge them?

module ActiveTableSet
  class PoolKey
    include ActiveTableSet::Constructable
    config_attribute :host,  required: true
    config_attribute :username,  required: true
    config_attribute :password,  required: true
    config_attribute :timeout,  required: true
    config_attribute :config,  required: true, class_name: "ActiveTableSet::DatabaseConfig"

    include AttrComparable
    attr_compare  :host, :username, :password, :timeout

    def clone_with_new_timeout(timeout)
      copy = self.clone_config do |clone|
        clone.timeout = timeout
        clone.config = config.clone_config { |db_config| db_config.timeout = timeout }
      end
    end

    def eql?(other_key)
      self.==(other_key)
    end

    def hash
      [host, username, password, timeout].hash
    end
  end
end
