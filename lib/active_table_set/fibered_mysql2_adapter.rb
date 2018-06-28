module ActiveTableSet
  class FiberedMysql2Adapter < ActiveRecord::ConnectionAdapters::EMMysql2Adapter
    def initialize(*args)
      super
    end

    # from active_record/connection_adapters/abstract_adapter.rb
    def lease
      synchronize do
        unless in_use?
          @owner = Fiber.current
        end
      end
    end
  end
end
