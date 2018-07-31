# frozen_string_literal: true

# This class behaves the same as ActiveRecord's ConnectionPool, but synchronizes with fibers rather than threads.

require 'em-synchrony'
require 'em-synchrony/thread'
require 'active_table_set/extensions/fibered_mutex_with_waiter_priority'

EventMachine::Synchrony::Thread::Mutex.prepend(ActiveTableSet::Extensions::FiberedMutexWithWaiterPriority)


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

    def initialize(connection_spec, table_set:)
      connection_spec.config[:reaping_frequency] and raise "reaping_frequency is not supported (the ActiveRecord Reaper is thread-based)"

      super(connection_spec, table_set: table_set)

      @reaper = nil   # no need to keep a reference to this since it does nothing in this sub-class

      # note that @reserved_connections is a ThreadSafe::Cache which is overkill in a fibered world, but harmless
    end

    def log_with_counts(method, message)
      ExceptionHandling.log_info("#{method}: Table set #{try(:table_set).inspect} for Fiber #{Fiber.current.object_id} [#{@available.instance_variable_get(:@queue).size}, #{@connections.size}, #{@size}]: #{message}")
    end

    def acquire_connection
      log_with_counts("0. acquire_connection", "about to @available_poll")
      if conn = @available.poll
        log_with_counts("1. acquire_connection", "got connection from @available")
        conn
      elsif @connections.size < @size
        log_with_counts("2. acquire_connection", "about to checkout_new_connection")
        checkout_new_connection.tap do
          log_with_counts("2. acquire_connection", "DONE")
        end
      else
        log_with_counts("3. acuire_connection", "about to reap")
        reap
        log_with_counts("3. acuire_connection", "about to poll for #{@checkout_timeout} seconds")
        @available.poll(@checkout_timeout).tap do
          log_with_counts("3. acuire_connection", "DONE")
        end
      end
    end

    def current_connection_id
      ActiveRecord::Base.connection_id ||= Fiber.current.object_id
    end

    def checkin(connection)
      ExceptionHandling.log_info("checkin: Table set #{try(:table_set).inspect} checking in connection for Fiber #{Fiber.current.object_id}")
      super
    end

    def checkout
      ExceptionHandling.ensure_safe("reap_connections") { reap_connections }
      ExceptionHandling.log_info("checkout: Table set #{try(:table_set).inspect} checking out connection for Fiber #{Fiber.current.object_id}")
      super
    end

    def reap_connections
      @reserved_connections.values.each do |connection|
        if connection.owner.alive?
          ExceptionHandling.log_info("reap_connections: Table set #{try(:table_set).inspect} connection still in use for Fiber #{connection.owner.object_id}")
        else
          ExceptionHandling.log_info("reap_connections: Table set #{try(:table_set).inspect} reaping connection for Fiber #{connection.owner.object_id}")
          checkin(connection)
        end
      end
    end
  end
end
