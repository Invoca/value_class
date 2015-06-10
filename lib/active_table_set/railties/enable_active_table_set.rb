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
    end
  end
end