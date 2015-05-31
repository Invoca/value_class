# Overrides ActiveRecord::Base.connection and adds in several additional methods
module ActiveTableSet
  module Extensions
    module ConnectionOverride
      extend ActiveSupport::Concern

      module ClassMethods
        def connection
          @@connection_proxy ||= ActiveTableSet.connection
        end
      end

      def self.prepended(base)
        class << base
          prepend ClassMethods
        end
      end
    end
  end
end
