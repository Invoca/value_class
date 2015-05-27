module ActiveTableSet
  module Configuration
    class Config
      include ValueClass::Constructable

      value_attr      :enforce_access_policy, default: false
      value_attr      :environment
      value_attr      :default_connection, class_name: 'ActiveTableSet::Configuration::DefaultConnection', required: true

      # TODO
      # - Keep a hash of table sets by name.
      # - assert that there is at least one table set.
      # - How to specify default database attributes?
      # - Specify named timeout values, disallow arbitrary values


      value_list_attr :table_sets,     class_name: 'ActiveTableSet::Configuration::TableSet', insert_method: :table_set

      def initialize(options={})
        super
        table_sets.any? or raise ArgumentError, "no table sets defined"
      end

      #
      #
      # def database_config(table_set:, access_mode: :write, partition_key: nil)
      #   ts = table_sets[table_set] or raise ArgumentError, "pool key requested from unknown table set #{table_set}"
      #   ts.database_config(access_mode: access_mode, partition_key: partition_key)
      # end
      #
      # def timeout_adjusted_database_config(table_set, access_mode, partition_key, timeout)
      #   key = database_config(table_set: table_set, access_mode: access_mode, partition_key: partition_key)
      #   timeout.nil? ? key : key.clone_with_new_timeout(timeout)
      # end
      #
    end
  end
end