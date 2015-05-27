module ActiveTableSet
  class Config
    include ValueClass::Constructable

    value_attr      :enforce_access_policy, default: false
    value_attr      :environment

    # TODO
    # - How to specify default database attributes
    # - How to specify default connection attributes?

    value_list_attr :table_sets,     class_name: 'ActiveTableSet::TableSet', insert_method: :table_set
  end
end
