# Overrides ActiveRecord::Base.connection and adds in several additional methods
module ActiveTableSet
  module Extensions
    module ConnectionOverride
      extend ActiveSupport::Concern

      module ClassMethods
        def connection
          @@connection_proxy ||= ActiveTableSet.connection_proxy
        end
      end
    end
  end
end
