#
# Partition represents a set of one leader and zero or more followers.
#

module ActiveTableSet
  module Configuration
    class Partition
      include ValueClass::Constructable

      value_attr      :partition_key
      value_attr      :leader,    class_name: 'ActiveTableSet::Configuration::DatabaseConfig'
      value_list_attr :followers, class_name: 'ActiveTableSet::Configuration::DatabaseConfig', insert_method: 'follower'

      def initialize(options={})
        super
        leader or raise ArgumentError, "must provide a leader"

        # Choose a follower based on the process id
        available_database_configs = [leader] + followers
        selected_index = self.class.pid % (available_database_configs.count)
        @chosen_follower = available_database_configs[selected_index]
      end

      def database_config(access_mode: :write)
        case access_mode
        when :write, :read
          leader
        when :balanced
          @chosen_follower
        else
          raise ArgumentError, "unknown access_mode"
        end
      end

      def self.pid
        $$
      end
    end
  end
end