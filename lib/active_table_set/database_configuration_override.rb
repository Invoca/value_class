module ActiveTableSet
  module DatabaseConfigurationOverride
    extend ActiveSupport::Concern
    # Over-ride the original defined in railties/lib/rails/application to not load from database.yml.
    # Returns a hash that should look just like it got loaded from database.yml.
    def database_configuration
      ActiveTableSet::DefaultConfigLoader.new.ar_configuration
    end
  end
end

# this will place ActiveTableSet::DatabaseConfigurationOverride at the front of the ancestor chain
module Rails
  class Application
    class Configuration
      prepend ActiveTableSet::DatabaseConfigurationOverride
    end
  end
end
