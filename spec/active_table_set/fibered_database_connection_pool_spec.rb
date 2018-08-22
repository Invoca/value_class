# frozen_string_literal: true

require 'spec_helper'
require 'active_table_set/fibered_database_connection_pool'
require 'rspec/mocks'
require 'active_record/connection_adapters/em_mysql2_adapter'

module ActiveTableSet
  class << self
    def clear_for_testing
      @config = nil
      @manager  = nil
    end
  end
end

class TestMonitor
  include ActiveTableSet::FiberedMonitorMixin

  attr_reader :mon_count, :condition

  def initialize
    mon_initialize

    @condition = new_cond
  end
end

describe ActiveTableSet::FiberedDatabaseConnectionPool do
  before do
    ActiveTableSet.clear_for_testing
    ActiveRecord::Base.default_connection_handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new

    @exceptions = []
    @next_ticks = []
    @trace      = []
    allow(ExceptionHandling).to receive(:log_error) { |*args| store_exception(args) }
    allow(EM).to receive(:next_tick) { |&block| queue_next_tick(&block) }
  end

  after do
    expect(@exceptions).to eq([])
  end

  describe ActiveTableSet::FiberedMonitorMixin do
    before do
      @monitor    = TestMonitor.new
    end

    it "should implement mutual exclusion" do
      @fibers = (0...2).map do
        Fiber.new do |i|
          trace "fiber #{i} begin"
          @monitor.synchronize do
            trace "fiber #{i} LOCK"
            trace "fiber #{i} yield"
            Fiber.yield
            trace "fiber #{i} UNLOCK"
          end
          trace "fiber #{i} end"
        end
      end

      resume 0
      resume 1
      resume 0
      resume 1

      expect(@trace).to eq([
                             "fiber 0 RESUME",
                             "fiber 0 begin",
                             "fiber 0 LOCK",
                             "fiber 0 yield",
                             "fiber 1 RESUME",
                             "fiber 1 begin",    # fiber 1 yields because it can't lock mutex
                             "fiber 0 RESUME",
                             "fiber 0 UNLOCK",
                             "next_tick queued",
                             # 1 yields back to 0
                             "fiber 0 end",
                             "next_tick.call",    # fiber 0 yields to fiber 1
                             "fiber 1 LOCK",
                             "fiber 1 yield",
                             "fiber 1 RESUME",
                             "fiber 1 UNLOCK",
                             "fiber 1 end"
                           ])
    end

    it "should keep a ref count on the mutex (yield after 1st lock)" do
      @fibers = (0...2).map do
        Fiber.new do |i|
          trace "fiber #{i} begin"
          @monitor.synchronize do
            trace "fiber #{i} LOCK #{@monitor.mon_count}"
            trace "fiber #{i} yield A"
            Fiber.yield
            @monitor.synchronize do
              trace "fiber #{i} LOCK #{@monitor.mon_count}"
              trace "fiber #{i} yield B"
              Fiber.yield
              trace "fiber #{i} UNLOCK #{@monitor.mon_count}"
            end
            trace "fiber #{i} UNLOCK #{@monitor.mon_count}"
          end
          trace "fiber #{i} end"
        end
      end

      resume 0
      resume 1
      resume 0
      resume 0
      resume 1
      resume 1

      expect(@trace).to eq([
                             "fiber 0 RESUME",
                             "fiber 0 begin",
                             "fiber 0 LOCK 1",
                             "fiber 0 yield A",
                             "fiber 1 RESUME",
                             "fiber 1 begin",
                                                  # fiber 1 yields because it can't get the lock
                             "fiber 0 RESUME",
                             "fiber 0 LOCK 2",
                             "fiber 0 yield B",
                             "fiber 0 RESUME",
                             "fiber 0 UNLOCK 2",
                             "fiber 0 UNLOCK 1",
                             "next_tick queued",
                             "fiber 0 end",
                             "next_tick.call",    # fiber 0 yields to fiber 1
                             "fiber 1 LOCK 1",
                             "fiber 1 yield A",
                             "fiber 1 RESUME",
                             "fiber 1 LOCK 2",
                             "fiber 1 yield B",
                             "fiber 1 RESUME",
                             "fiber 1 UNLOCK 2",
                             "fiber 1 UNLOCK 1",
                             "fiber 1 end"
                           ])
    end

    it "should keep a ref count on the mutex (yield after 2nd lock)" do
      @fibers = (0...2).map do
        Fiber.new do |i|
          trace "fiber #{i} begin"
          @monitor.synchronize do
            trace "fiber #{i} LOCK #{@monitor.mon_count}"
            trace "fiber #{i} yield A"
            Fiber.yield
            @monitor.synchronize do
              trace "fiber #{i} LOCK #{@monitor.mon_count}"
              trace "fiber #{i} yield B"
              Fiber.yield
              trace "fiber #{i} UNLOCK #{@monitor.mon_count}"
            end
            trace "fiber #{i} UNLOCK #{@monitor.mon_count}"
          end
          trace "fiber #{i} end"
        end
      end

      resume 0
      resume 0
      resume 1
      resume 0
      resume 1
      resume 1

      expect(@trace).to eq([
                             "fiber 0 RESUME",
                             "fiber 0 begin",
                             "fiber 0 LOCK 1",
                             "fiber 0 yield A",
                             "fiber 0 RESUME",
                             "fiber 0 LOCK 2",
                             "fiber 0 yield B",
                             "fiber 1 RESUME",
                             "fiber 1 begin",
                                                 # fiber 1 yields because it can't get the lock
                             "fiber 0 RESUME",
                             "fiber 0 UNLOCK 2",
                             "fiber 0 UNLOCK 1",
                             "next_tick queued",
                             "fiber 0 end",
                             "next_tick.call",    # fiber 0 yields to fiber 1
                             "fiber 1 LOCK 1",
                             "fiber 1 yield A",
                             "fiber 1 RESUME",
                             "fiber 1 LOCK 2",
                             "fiber 1 yield B",
                             "fiber 1 RESUME",
                             "fiber 1 UNLOCK 2",
                             "fiber 1 UNLOCK 1",
                             "fiber 1 end"
                           ])
    end

    it "should implement wait/signal on the condition with priority over other mutex waiters" do
      @fibers = (0...3).map do
        Fiber.new do |i, condition_handling|
          trace "fiber #{i} begin"
          @monitor.synchronize do
            trace "fiber #{i} LOCK #{@monitor.mon_count}"
            @monitor.synchronize do
              trace "fiber #{i} LOCK #{@monitor.mon_count}"
              trace "fiber #{i} yield"
              Fiber.yield
              case condition_handling
              when :wait
                trace "fiber #{i} WAIT"
                @monitor.condition.wait
                trace "fiber #{i} UNWAIT"
              when :signal
                trace "fiber #{i} SIGNAL"
                @monitor.condition.signal
                trace "fiber #{i} UNSIGNAL"
              end
              trace "fiber #{i} UNLOCK #{@monitor.mon_count}"
            end
            trace "fiber #{i} UNLOCK #{@monitor.mon_count}"
          end
          trace "fiber #{i} end"
        end
      end

      resume 0, :wait
      resume 1, :signal
      resume 2, nil
      resume 0
      resume 1
      resume 2

      expect(@trace).to eq([
                             "fiber 0 RESUME",
                             "fiber 0 begin",
                             "fiber 0 LOCK 1",
                             "fiber 0 LOCK 2",    # fiber 0 locks the mutex
                             "fiber 0 yield",
                             "fiber 1 RESUME",
                             "fiber 1 begin",
                                                  # fiber 1 yields because it can't lock the mutex
                             "fiber 2 RESUME",
                             "fiber 2 begin",
                                                  # fiber 2 yields because it can't lock the mutex
                             "fiber 0 RESUME",
                             "fiber 0 WAIT",
                             "next_tick queued",
                                                  # fiber 0 yields while waiting for condition to be signaled
                             "next_tick.call",    # fiber 0 yields mutex to fiber 1
                             "fiber 1 LOCK 1",
                             "fiber 1 LOCK 2",
                             "fiber 1 yield",
                             "fiber 1 RESUME",
                             "fiber 1 SIGNAL",
                             "next_tick queued",
                             "fiber 1 UNSIGNAL",
                             "fiber 1 UNLOCK 2",
                             "fiber 1 UNLOCK 1",
                             "next_tick queued",
                             "fiber 1 end",
                             "next_tick.call",
                             "next_tick.call",    # fiber 1 yields to fiber 0 that was waiting for the signal (this takes priority over fiber 2 that was already waiting on the mutex)
                             "fiber 0 UNWAIT",
                             "fiber 0 UNLOCK 2",
                             "fiber 0 UNLOCK 1",
                             "next_tick queued",
                             "fiber 0 end",
                             "next_tick.call",
                             "fiber 2 LOCK 1",
                             "fiber 2 LOCK 2",
                             "fiber 2 yield",
                             "fiber 2 RESUME",
                             "fiber 2 UNLOCK 2",
                             "fiber 2 UNLOCK 1",
                             "fiber 2 end"
                           ])
    end
  end

  describe ActiveRecord::ConnectionAdapters::ConnectionPool::Queue do
    before do
      @timers     = []
      allow(EM).to receive(:add_timer) { |&block| queue_timer(&block); block }
      allow(EM).to receive(:cancel_timer) { |block| cancel_timer(block) }
    end

    describe "poll" do
      it "should return added entries immediately" do
        spec = ActiveRecord::ConnectionAdapters::ConnectionSpecification.new({ database: 'rr_prod', host: 'master.ringrevenue.net' }, :em_mysql2)
        cp = ActiveTableSet::FiberedDatabaseConnectionPool.new(spec, table_set: :common)
        queue = cp.instance_variable_get(:@available)
        queue.add(1)
        polled = []
        fiber = Fiber.new { polled << queue.poll(1) }
        fiber.resume
        expect(polled).to eq([1])
      end

      it "should block when queue is empty" do
        spec = ActiveRecord::ConnectionAdapters::ConnectionSpecification.new({ database: 'rr_prod', host: 'master.ringrevenue.net' }, :em_mysql2)
        cp = ActiveTableSet::FiberedDatabaseConnectionPool.new(spec, table_set: :common)
        queue = cp.instance_variable_get(:@available)
        polled = []
        fiber = Fiber.new { polled << queue.poll(10) }
        fiber.resume
        queue.add(1)
        run_next_ticks
        expect(polled).to eq([1])
      end
    end
  end

  describe ActiveRecord::ConnectionAdapters::ConnectionPool do
    it "should serve separate connections per fiber" do
      configure_ats_like_ringswitch
      ActiveTableSet.enable

      connection_stub = Object.new
      allow(connection_stub).to receive(:query_options) { {} }
      expect(connection_stub).to receive(:query) do |*args|
        expect(args).to eq(["SET SQL_AUTO_IS_NULL=0, NAMES 'utf8', @@wait_timeout = 2147483"])
      end.exactly(2).times
      allow(connection_stub).to receive(:ping) { true }
      allow(connection_stub).to receive(:close)

      allow(Mysql2::EM::Client).to receive(:new) { |config| connection_stub }

      c0 = ActiveRecord::Base.connection
      c1 = nil
      fiber = Fiber.new { c1 = ActiveRecord::Base.connection }
      fiber.resume

      expect(c0).to be
      expect(c1).to be
      expect(c1).to_not eq(c0)
      expect(c0.owner).to eq(Fiber.current)
      expect(c1.owner).to eq(fiber)
      expect(c0.in_use?).to be
      expect(c1.in_use?).to be
    end

    it "should reclaim connections when the fiber has exited (and log details)" do
      configure_ats_like_ringswitch
      ActiveTableSet.enable

      connection_stub = String.new
      allow(connection_stub).to receive(:query_options) { {} }
      expect(connection_stub).to receive(:query) { }.exactly(2).times
      allow(connection_stub).to receive(:ping) { true }
      allow(connection_stub).to receive(:close).at_least(1).times
      expect_any_instance_of(ActiveTableSet::FiberedDatabaseConnectionPool).to receive(:reap_connections).with(no_args).exactly(3).times.and_call_original

      allow(Mysql2::EM::Client).to receive(:new) { |config| connection_stub }

      c0 = ActiveRecord::Base.connection
      c1 = nil

      fiber1 = Fiber.new { c1 = ActiveRecord::Base.connection }

      c2 = nil
      fiber2 = Fiber.new { c2 = ActiveRecord::Base.connection }

      expect(ExceptionHandling).to receive(:log_info).with(/reap_connections: Table set ringswitch-110 connection still in use for Fiber #{Fiber.current.object_id}/)
      expect(ExceptionHandling).to receive(:log_info).with(satisfy { |arg| arg =~ /0\. acquire_connection:/ }).exactly(2).times
      expect(ExceptionHandling).to receive(:log_info).with("checkout: Table set ringswitch-110 checking out connection for Fiber #{fiber1.object_id}")
      expect(ExceptionHandling).to receive(:log_info).with(satisfy { |arg| arg =~ /2\. acquire_connection:/ }).exactly(2).times
      expect(ExceptionHandling).to receive(:log_info).with("checkout: Table set ringswitch-110 checking out connection for Fiber #{fiber2.object_id}")
      expect(ExceptionHandling).to receive(:log_info).with("checkin: Table set ringswitch-110 checking in connection for Fiber #{fiber2.object_id}")
      expect(ExceptionHandling).to receive(:log_info).with(satisfy { |arg| arg =~ /1\. acquire_connection:/ })
      expect(ExceptionHandling).to receive(:log_info).with(/reap_connections: Table set ringswitch-110 reaping connection for Fiber #{fiber1.object_id}/)
      expect(ExceptionHandling).to receive(:log_info).with(/reap_connections: Table set ringswitch-110 connection still in use for Fiber #{Fiber.current.object_id}/)

      fiber1.resume

      expect(c1.owner).to eq(fiber1)

      fiber2.resume

      expect(c2.owner).to eq(fiber2)

      expect(c1.object_id).to eq(c2.object_id)
    end

    it "should hand off connection on checkin to any fiber waiting on checkout" do
      configure_ats_like_ringswitch
      ActiveTableSet.enable

      connection_stub = String.new
      allow(connection_stub).to receive(:query_options) { {} }
      expect(connection_stub).to receive(:query) { }.exactly(2).times
      allow(connection_stub).to receive(:ping) { true }
      allow(connection_stub).to receive(:close).at_least(1).times
      expect_any_instance_of(ActiveTableSet::FiberedDatabaseConnectionPool).to receive(:reap_connections).with(no_args).exactly(3).times.and_call_original

      allow(Mysql2::EM::Client).to receive(:new) { |config| connection_stub }

      EM.run do
        ActiveTableSet.using(table_set: :ringswitch_jobs) do
          c0 = ActiveRecord::Base.connection
          c1 = nil
          fiber1 = Fiber.new do
            c1 = ActiveTableSet.using(table_set: :ringswitch_jobs) do
              ActiveRecord::Base.connection
            end
          end

          fiber1.resume
          expect(c1).to eq(nil) # should block because there is only one connection

          ExceptionHandling.log_info "about to sleep(1)"
          sleep(1)
          c0.pool.checkin(c0)

          ExceptionHandling.log_info "back from sleep(1)"

          expect(c1).to eq(c0)

          EM.stop
        end
      end
    end

    describe "connection_pool_stats" do
      it "should return a hash of stats" do
        configure_ats_like_ringswitch
        ActiveTableSet.enable

        connection_stub = Object.new
        allow(connection_stub).to receive(:query_options) { {} }
        expect(connection_stub).to receive(:query) { }.exactly(4).times
        allow(connection_stub).to receive(:ping) { true }
        allow(connection_stub).to receive(:close).exactly(4).times

        allow(Mysql2::EM::Client).to receive(:new) { |config| connection_stub }

        c0 = ActiveRecord::Base.connection
        fiber1 = Fiber.new { c1 = ActiveRecord::Base.connection; Fiber.yield }
        fiber2 = Fiber.new { c1 = ActiveRecord::Base.connection; Fiber.yield }
        fiber3 = Fiber.new { c1 = ActiveRecord::Base.connection; Fiber.yield }
        fiber1.resume # bump in_use and allocated to 2
        fiber2.resume # bump in_use and allocated to 3
        fiber1.resume # allow fiber to exit (so connection can be reclaimed)
        fiber2.resume #   "      "   "   "    "    "        "   "   "
        fiber3.resume # reset in_use to 2 but allocated will stay at 3

        ActiveTableSet.using(table_set: :ringswitch_jobs, timeout: 25) do
          ActiveRecord::Base.connection
        end

        stats = ActiveTableSet.manager.connection_pool_stats

        expect(stats).to eq(
            "ringswitch-110"     => { allocated: 3, in_use: 2 },
            "ringswitch_jobs-25" => { allocated: 1, in_use: 0 }
        )
      end
    end
  end

private
  def trace(message)
    @trace << message
  end

  def queue_next_tick(&block)
    block or raise "Nil block passed!"
    trace "next_tick queued"
    @next_ticks << block
  end

  def run_next_ticks
    while (next_tick_block = @next_ticks.shift)
      @trace << "next_tick.call"
      next_tick_block.call
    end
  end

  def resume(fiber, *args)
    trace "fiber #{fiber} RESUME"
    @fibers[fiber].resume(fiber, *args)
    run_next_ticks
  end

  def queue_timer(&block)
    @timers << block
  end

  def cancel_timer(timer_block)
    @timers.delete_if { |block| block == timer_block }
  end

  def store_exception(args)
    @exceptions << args
  end
end
