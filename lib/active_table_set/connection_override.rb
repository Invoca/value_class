require 'active_record'
require 'active_table_set/default_config_loader'

# Overrides ActiveRecord::Base
# include ConnectionOverride in your ApplicationModel class
module ActiveTableSet
  module ConnectionOverride
    extend ActiveSupport::Concern

    module ClassMethods
      def ats_config
        ActiveTableSet::DefaultConfigLoader.new
      end

      def connection
        @@connection_proxy ||= proxy_with_default_table_set
      end

      def proxy_with_default_table_set
        proxy = ActiveTableSet::ConnectionProxy.new(config: ats_config.configuration)
        proxy.set_default_table_set(table_set_name: "common")
        proxy
      end
    end
  end
end

ActiveRecord::Base.send :include, ActiveTableSet::ConnectionOverride
