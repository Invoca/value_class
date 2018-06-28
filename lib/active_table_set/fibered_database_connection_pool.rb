# This class behaves the same as ActiveRecord's ConnectionPool, but synchronizes with fibers rather than threads.

require 'em-synchrony'
require 'em-synchrony/thread'
require 'active_table_set/extensions/fibered_mutex_with_waiter_priority'

EventMachine::Synchrony::Thread::Mutex.prepend ActiveTableSet::Extensions::FiberedMutexWithWaiterPriority


module ActiveTableSet
  class FiberedConditionVariable < MonitorMixin::ConditionVariable
    def initialize(monitor)
      @monitor = monitor
      @cond = EM::Synchrony::Thread::ConditionVariable.new
    end
  end

  # From Ruby's MonitorMixin, with all occurrences of Thread changed to Fiber
  module FiberedMonitorMixin
    def self.extend_object(obj)
      super
      obj.__send__(:mon_initialize)
    end

    #
    # Attempts to enter exclusive section.  Returns +false+ if lock fails.
    #
    def mon_try_enter
      if @mon_owner != Fiber.current
        @mon_mutex.try_lock or return false
        @mon_owner = Fiber.current
        @mon_count = 0
      end
      @mon_count += 1
      true
    end

    #
    # Enters exclusive section.
    #
    def mon_enter
      if @mon_owner != Fiber.current
        @mon_mutex.lock
        @mon_owner = Fiber.current
        @mon_count = 0
      end
      @mon_count += 1
    end

    #
    # Leaves exclusive section.
    #
    def mon_exit
      mon_check_owner
      @mon_count -= 1
      if @mon_count == 0
        @mon_owner = nil
        @mon_mutex.unlock
      end
    end

    #
    # Enters exclusive section and executes the block.  Leaves the exclusive
    # section automatically when the block exits.  See example under
    # +MonitorMixin+.
    #
    def mon_synchronize
      mon_enter
      begin
        yield
      ensure
        ExceptionHandling.ensure_safe("mon_exit") do
          mon_exit
        end
      end
    end
    alias synchronize mon_synchronize

    #
    # Creates a new FiberedConditionVariable associated with the
    # receiver.
    #
    def new_cond
      FiberedConditionVariable.new(self)
    end

    private

    # Initializes the FiberedMonitorMixin after being included in a class
    def mon_initialize
      @mon_owner = nil
      @mon_count = 0
      @mon_mutex = EM::Synchrony::Thread::Mutex.new
    end

    def mon_check_owner
      @mon_owner == Fiber.current or raise FiberError, "current fiber not owner"
    end

    def mon_enter_for_cond(count)
      @mon_owner = Fiber.current
      @mon_count = count
    end

    # returns the old mon_count
    def mon_exit_for_cond
      count = @mon_count
      @mon_owner = nil
      @mon_count = 0
      count
    end
  end

  class FiberedDatabaseConnectionPool < ActiveRecord::ConnectionAdapters::ConnectionPool
    include FiberedMonitorMixin

    def initialize(connection_spec)
      connection_spec.config[:reaping_frequency] and raise "reaping_frequency is not supported (the ActiveRecord Reaper is thread-based)"

      super

      @reaper = nil   # no need to keep a reference to this since it does nothing

      # note that @reserved_connections is a ThreadSafe::Cache which is overkill in a fibered world, but harmless
    end

    def current_connection_id
      ActiveRecord::Base.connection_id ||= Fiber.current.object_id
    end

    def checkout
      ExceptionHandling.ensure_safe("checkin_dead_connections") { checkin_dead_connections }
      super
    end

    private

    def checkin_dead_connections
      @reserved_connections.values.each do |connection|
        if !connection.owner.alive?
          checkin(connection)
        end
      end
    end
  end
end
