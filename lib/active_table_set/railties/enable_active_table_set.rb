# frozen_string_literal: true

module ActiveTableSet
  module Railties
    class EnableActiveTableSet < ::Rails::Railtie
      initializer "active_record.initialize_active_table_set", before: "active_record.initialize_database" do |app|
        ActiveSupport.on_load(:active_record) do
          if ActiveTableSet.configured?
            ActiveTableSet.enable
          end
        end
      end

      initializer "active_table_set.test_database", after: "active_record.initialize_database" do |app|
        ActiveSupport.on_load(:active_record) do
          if ActiveTableSet.configured? && ActiveTableSet.configuration.default_test_scenario
            ActiveTableSet.use_test_scenario(ActiveTableSet.configuration.default_test_scenario)

            # TODO: Set class table sets.
          end
        end
      end
    end
  end
end
