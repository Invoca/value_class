require 'spec_helper'
require 'active_table_set/fibered_database_connection_pool'
require 'rspec/mocks'

class TestMonitor
  include ActiveTableSet::FiberedMonitorMixin

  attr_reader :mon_count, :condition

  def initialize
    mon_initialize

    @condition = new_cond
  end
end

describe ActiveTableSet::FiberedDatabaseConnectionPool do
  describe ActiveTableSet::FiberedMonitorMixin do
    before do
      @monitor    = TestMonitor.new
      @next_ticks = []
      @trace      = []
      allow(EM).to receive(:next_tick) { |&block| queue_next_tick(&block) }
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
                             "fiber 0 LOCK 2",
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
                                                  # fiber 0 yields while waiting for signal
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
                             "next_tick.call",
                             "fiber 2 LOCK 1",
                             "fiber 2 LOCK 2",
                             "fiber 2 yield",
                             "fiber 2 RESUME",
                             "fiber 2 UNLOCK 2",
                             "fiber 2 UNLOCK 1",
                             "next_tick queued",
                             "fiber 2 end",
                             "next_tick.call",
                             "fiber 0 UNWAIT",
                             "fiber 0 UNLOCK 2",
                             "fiber 0 UNLOCK 1",
                             "fiber 0 end"
                           ])
    end
  end

  # context "construction" do
  #   it "has a Queue" do
  #     queue = ActiveTableSet::FiberedDatabaseConnectionPool::Queue.new
  #     binding.pry
  #   end
  # end

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
end
