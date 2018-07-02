# frozen_string_literal: true

module ActiveTableSet
  ConnectionAttributes = ValueClass.struct(:pool_key, :access_policy, :failover_pool_key)
end
