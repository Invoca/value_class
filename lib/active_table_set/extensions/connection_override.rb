# Overrides ActiveRecord::Base.connection and adds in several additional methods
_ = ActiveTableSet
module ActiveTableSet
  module Extensions
    module ConnectionOverride
      def connection
        ActiveTableSet.connection
      end
    end
  end
end
