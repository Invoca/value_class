# Overrides ActiveRecord::Base.connection and adds in several additional methods
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
        proxy = ActiveTableSet::ConnectionProxy.new(config: ats_config.ats_configuration)
        proxy.set_default_table_set(table_set_name: "common")
        proxy
      end
    end

    def self.prepended(base)
      class << base
        prepend ClassMethods
      end
    end
  end
end

# TODO - move to enabled method.
# this will place ActiveTableSet::ConnectionOverride at the front of the ancestor chain
module ActiveRecord
  class Base
    prepend ActiveTableSet::ConnectionOverride
  end
end
