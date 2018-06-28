module ActiveTableSet
  class FiberedMysql2Adapter < ActiveRecord::ConnectionAdapters::EMMysql2Adapter
    attr_reader :fiber_owner

    def initialize(*args)
      super
      @fiber_owner = nil
    end

    def owner
      raise ArgumentError, "[thread] owner is deprecated here. Use fiber_owner."
    end

    def in_use?
      !@fiber_owner.nil?
    end

    # from active_record/connection_adapters/abstract_adapter.rb
    def lease
      synchronize do
        unless in_use?
          @fiber_owner = Fiber.current
        end
      end
    end

    def expire
      @fiber_owner = nil
    end
  end
end
