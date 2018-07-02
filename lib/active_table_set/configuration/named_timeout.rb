# frozen_string_literal: true

module ActiveTableSet
  module Configuration
    NamedTimeout = ValueClass.struct(:name, :timeout, required: true)
  end
end
