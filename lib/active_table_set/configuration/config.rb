module ActiveTableSet
  module Configuration
    class Config
      include ValueClass::Constructable

      value_attr      :enforce_access_policy, default: false
      value_attr      :environment
      value_attr      :default_connection, class_name: 'ActiveTableSet::Configuration::DefaultConnection', required: true
      value_list_attr :table_sets,     class_name: 'ActiveTableSet::Configuration::TableSet', insert_method: :table_set

      # TODO -- How to specify default database attributes?
      # TODO -- Specify named timeout values, disallow arbitrary values  For example :web, 110 seconds,  :bulk = 15 minutes... :ringswitch_event_processor - 1 second.   :ringswitch_deferred - 15 seconds
      # TODO -- Define test_scenario config and implement.
      # TODO -- Define method to return list of DB connections.
      # TODO -- Add description for all config parameters.
      # TODO -- Define users outside of DB spec?



      def initialize(options={})
        super
        table_sets.any? or raise ArgumentError, "no table sets defined"
        @table_sets_by_name = table_sets.inject({}) { |memo, ts| memo[ts.name] = ts; memo }
      end

      def database_config(table_set:, access_mode: :write, partition_key: nil)
        ts = @table_sets_by_name[table_set] or raise ArgumentError, "Unknown table set #{table_set}, available_table_sets: #{@table_sets_by_name.keys.sort.join(", ")}"
        ts.database_config(access_mode: access_mode, partition_key: partition_key)
      end
    end
  end
end