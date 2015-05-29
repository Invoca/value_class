module ActiveTableSet
  module Extensions
    module DatabaseConfigurationOverride
      extend ActiveSupport::Concern

      # Over ride the original defined in railties/lib/rails/application to not load from database.yml.
      # Returns a hash that should look just like it got loaded from database.yml.
      def database_configuration
        ActiveTableSet.database_configuration
      end
    end
  end
end

