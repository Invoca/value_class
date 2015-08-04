module ActiveTableSet
  module Extensions
    module MigrationExtension

      def up
        ActiveTableSet.using(timeout: ActiveTableSet.configuration.migration_timeout) do
          super
        end
      end

      def down
        ActiveTableSet.using(timeout: ActiveTableSet.configuration.migration_timeout) do
          super
        end
      end
    end
  end
end
