# frozen_string_literal: true

module ActiveTableSet
  module Configuration
    ClassTableSet = ValueClass.struct(:class_name, :table_set, required: true)
  end
end
