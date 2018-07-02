# frozen_string_literal: true

module ActiveTableSet
  module Extensions
    module MigrationExtension
      def migrate(direction)
        ActiveTableSet.using(timeout: ActiveTableSet.configuration.migration_timeout) do
          super
        end
      end
    end
  end
end
