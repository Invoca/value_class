# frozen_string_literal: true

require 'spec_helper'

describe ActiveTableSet::ConnectionManager do
  context "construction" do
    it "raises on missing config parameters" do
      expect { ActiveTableSet::ConnectionManager.new }.to raise_error(ArgumentError, "missing keywords: config, connection_handler")
    end
  end

  context "with a stubbed pool manager" do
    let(:connection_pool)    { StubConnectionPool.new }
    let(:connection_handler) { StubConnectionHandler.new }
    let(:connection_manager) do
      allow(ActiveTableSet::Configuration::Partition).to receive(:pid).and_return(1)
      ActiveTableSet::ConnectionManager.new(config: large_table_set, connection_handler: connection_handler )
    end

    it "provides a default spec" do
      connection_manager
      expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
    end

    context "using" do
      it "allows timeouts to be overidden without a block" do
        connection_manager
        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
        expect(connection_handler.current_config["read_timeout"]).to eq(110)
        expect(connection_handler.current_config["write_timeout"]).to eq(110)

        handler = connection_manager.using(timeout: 30)
        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
        expect(connection_handler.current_config["read_timeout"]).to eq(30)
        expect(connection_handler.current_config["write_timeout"]).to eq(30)

        handler.reset
        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
        expect(connection_handler.current_config["read_timeout"]).to eq(110)
        expect(connection_handler.current_config["write_timeout"]).to eq(110)
      end

      it "allows timeouts to be overidden" do
        connection_manager
        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
        expect(connection_handler.current_config["read_timeout"]).to eq(110)
        expect(connection_handler.current_config["write_timeout"]).to eq(110)

        connection_manager.using(timeout: 30) do
          expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
          expect(connection_handler.current_config["read_timeout"]).to eq(30)
          expect(connection_handler.current_config["write_timeout"]).to eq(30)
        end

        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
        expect(connection_handler.current_config["read_timeout"]).to eq(110)
        expect(connection_handler.current_config["write_timeout"]).to eq(110)
      end

      it "allows connections to different table sets" do
        connection_manager
        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")

        connection_manager.using(table_set: :sharded, partition_key: "alpha") do
          expect(connection_handler.current_config["host"]).to eq("11.0.1.1")
        end

        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
      end

      it "supports nesting, and clears partition key when table set changes" do
        connection_manager
        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")

        connection_manager.using(table_set: :sharded, partition_key: "alpha") do
          expect(connection_handler.current_config["host"]).to eq("11.0.1.1")

          connection_manager.using(table_set: :common) do
            expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
          end

          expect(connection_handler.current_config["host"]).to eq("11.0.1.1")
        end

        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
      end

      it "allows balanced connections" do
        connection_manager
        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
        expect(connection_handler.current_config["username"]).to eq("tester")
        expect(connection_handler.current_config["password"]).to eq("verysecure")

        connection_manager.using(access: :balanced) do
          expect(connection_handler.current_config["host"]).to eq("10.0.0.2")
          expect(connection_handler.current_config["username"]).to eq("read_only_tester_follower")
          expect(connection_handler.current_config["password"]).to eq("verysecure_too_follower")
        end

        expect(connection_handler.current_config["username"]).to eq("tester")
        expect(connection_handler.current_config["password"]).to eq("verysecure")
      end

      it "allows using to be called before a connection is established" do
        connection_manager.using(access: :balanced) do
          expect(connection_handler.current_config["host"]).to eq("10.0.0.2")
        end
      end

      it "resets the connection if an exception is raised in using block" do
        connection_manager
        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")

        connection_manager.using(table_set: :sharded, partition_key: "alpha") do
          expect(connection_handler.current_config["host"]).to eq("11.0.1.1")

          expect do
            connection_manager.using(table_set: :common) do
              raise ArgumentError, "boom"
            end
          end.to raise_exception(ArgumentError)

          expect(connection_handler.current_config["host"]).to eq("11.0.1.1")
        end

        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
      end

      it "should pass through exception from establish_connection" do
        connection_manager.using(table_set: :sharded, partition_key: "alpha") do
          expect(connection_handler.current_config["host"]).to eq("11.0.1.1")

          raise_count = 0
          expect(connection_manager).to receive(:establish_connection) { raise RuntimeError, "establish error" if (raise_count += 1) == 1 }.exactly(3).times
          expect do
            connection_manager.using(table_set: :common) { }
          end.to raise_exception(RuntimeError, /establish error/)
        end
      end

      it "passes through exception from establish_connection and ensure_safe around reset" do
        connection_manager.using(table_set: :sharded, partition_key: "alpha") do
          expect(connection_handler.current_config["host"]).to eq("11.0.1.1")

          expect(ExceptionHandling).to receive(:log_error).with(instance_of(RuntimeError), /override_with_new_connection: resetting/)

          raise_count = 0
          expect(connection_manager).to receive(:establish_connection) { raise RuntimeError, "establish error" if (raise_count += 1) <= 2 }.exactly(3).times
          expect do
            connection_manager.using(table_set: :common) { }
          end.to raise_exception(RuntimeError, /establish error/)
        end
      end

      it "wraps ensure_safe around reestablish if exception happens from reset" do
        connection_manager.using(table_set: :sharded, partition_key: "alpha") do
          expect(connection_handler.current_config["host"]).to eq("11.0.1.1")

          expect(ExceptionHandling).to receive(:log_error).with(instance_of(RuntimeError), /using resetting with old settings/)
          raise_count = 0
          expect(connection_manager).to receive(:establish_connection) { raise RuntimeError, "establish error" if (raise_count += 1) == 2 }.exactly(3).times
          expect do
            connection_manager.using(table_set: :common) do
              raise ArgumentError, "boom"
            end
          end.to raise_exception(ArgumentError)
        end
      end

      it "resets even multiple levels of nesting if exceptions occur" do
        connection_manager
        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")

        expect do
          connection_manager.using(table_set: :sharded, partition_key: "alpha") do
            expect(connection_handler.current_config["host"]).to eq("11.0.1.1")
            connection_manager.using(table_set: :common) do
              raise ArgumentError, "boom"
            end
          end
        end.to raise_exception(ArgumentError)

        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
      end

      it "resets if an exception occurs while resetting" do
        connection_manager
        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
        received_exception = nil
        allow(connection_manager).to receive(:release_connection) { raise "Raised an exception" }
        begin
          connection_manager.using(table_set: :sharded, partition_key: "alpha") {}
        rescue Exception => ex
          received_exception = ex
        end
        expect(received_exception&.message).to eq("Raised an exception")
        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
      end

      it "should not call the before_enable lambda if it is not defined on the table set" do
        connection_manager
        expect(Proc).not_to receive(:new)

        connection_manager.using(table_set: :common, partition_key: "alpha") do
        end
      end

      it "should call the before_enable lambda if it is defined on the table set" do
        connection_manager
        expect(Proc).to receive(:new)

        connection_manager.using(table_set: :sharded, partition_key: "alpha") do
        end
      end
    end

    context "use_test_scenario" do
      it "overrides the access policy, but not the connection (which may be made on a new fiber)" do
        connection_manager
        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")

        connection_manager.use_test_scenario("legacy")
        expect(connection_manager.access_policy.disallow_read).to eq("cf_%")
        expect(connection_handler.current_config["host"]).to eq("12.0.0.1")

        connection_manager.using(table_set: :sharded, partition_key: "alpha") do
          expect(connection_handler.current_config["host"]).to eq("12.0.0.1")

          expect(connection_manager.access_policy.disallow_read).to eq("")

          connection_manager.using(table_set: :common) do
            expect(connection_handler.current_config["host"]).to eq("12.0.0.1")
            expect(connection_manager.access_policy.disallow_read).to eq("cf_%")

            connection_manager.using(access: :follower) do
              expect(connection_handler.current_config["host"]).to eq("12.0.0.1")
              expect(connection_manager.access_policy.disallow_write).to eq("%")
            end

            connection_manager.allow_test_access do
              expect(connection_manager.access_policy).to eq(nil)
            end
          end

          expect(connection_handler.current_config["host"]).to eq("12.0.0.1")
          expect(connection_manager.access_policy.disallow_read).to eq("")
          Fiber.new { expect(connection_manager.send(:settings).test_scenario).to eq("legacy") }.resume
        end

        expect(connection_handler.current_config["host"]).to eq("12.0.0.1")
        expect(connection_manager.access_policy.disallow_read).to eq("cf_%")
      end

      it "can be called before a connection is made" do
        connection_manager
        connection_manager.use_test_scenario("legacy")
      end
    end

    context "access_lock" do
      it "silently overrides other access modes" do
        connection_manager
        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")

        connection_manager.lock_access(:leader) do
          expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
          connection_manager.using(access: :balanced) do
            expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
            connection_manager.using(access: :follower) do
              expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
            end
          end
        end

        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
        connection_manager.using(access: :balanced) do
          expect(connection_handler.current_config["host"]).to eq("10.0.0.2")

          connection_manager.using(access: :follower) do
            expect(connection_handler.current_config["host"]).to eq("10.0.0.2")
          end
        end
      end

      it "changes the connection back if it is set differently" do
        connection_manager
        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
        connection_manager.using(access: :balanced) do
          expect(connection_handler.current_config["host"]).to eq("10.0.0.2")
          connection_manager.lock_access(:leader) do
            expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
          end
          expect(connection_handler.current_config["host"]).to eq("10.0.0.2")
        end
      end
    end

    context "disable_alternate_databases process flag" do
      it "forces all access to the leader" do
        connection_manager
        allow(ProcessFlags).to receive(:is_set?).with(:disable_alternate_databases) { true }
        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")

        connection_manager.lock_access(:follower) do
          expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
          connection_manager.using(access: :balanced) do
            expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
            connection_manager.using(access: :follower) do
              expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
            end
          end
        end

        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
        connection_manager.using(access: :balanced) do
          expect(connection_handler.current_config["host"]).to eq("10.0.0.1")

          connection_manager.using(access: :follower) do
            expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
          end
        end
      end
    end


    it "supports different settings for different threads" do
      connection_manager
      @thread_initial_host = nil
      @thread_shard_host = nil
      @thread_nested_host = nil

      expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
      connection_manager.using(table_set: :sharded, partition_key: "alpha") do
        expect(connection_handler.current_config["host"]).to eq("11.0.1.1")

        t = Thread.new do
          @thread_initial_host = connection_handler.current_config["host"]
          connection_manager.using(table_set: :sharded, partition_key: "beta") do
            @thread_shard_host = connection_handler.current_config["host"]
          end
        end
        t.join

        expect(connection_handler.current_config["host"]).to eq("11.0.1.1")
      end

      expect(connection_handler.current_config["host"]).to eq("10.0.0.1")

      expect(@thread_initial_host).to eq("10.0.0.1")
      expect(@thread_shard_host).to   eq("11.0.2.1")
    end

    it "disconnects from connections when done with them" do
      connection_manager

      dbl = double("dbl")
      allow(connection_handler).to receive(:pool_for_spec) { dbl }
      expect(dbl).to receive(:connection).twice
      expect(dbl).to receive(:release_connection)

      connection_manager.using(table_set: :sharded, partition_key: "alpha") {}
    end

    context "failover and quarantine" do
      it "log errors and fail back to initial connection when a connection failure occurs" do
        TestLog.clear_log

        connection_manager
        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")

        Time.now_override = Time.now

        # First connection fails, log an exception and revert to previous setting
        ActiveRecord::Base.set_next_client_exception(ArgumentError, "badaboom")
        connection_manager.using(access: :balanced) do
          expect(TestLog.logged_lines.second).to match(/badaboom/)
          expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
        end

        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")

        # Connect again, should not try to connect - quarantined!
        connection_manager.using(access: :balanced) do
          expect(TestLog.logged_lines.first).to eq(nil)
          expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
        end

        # Connect again, after the quarantine
        Time.now_override = Time.now + 120
        connection_manager.using(access: :balanced) do
          expect(TestLog.logged_lines.first).to eq(nil)
          expect(connection_handler.current_config["host"]).to eq("10.0.0.2")
        end
      end

      it "should error all the way out when the failover connection also fails" do
        connection_manager
        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")

        allow(connection_manager).to receive(:establish_connection_using_spec) do
          raise "BoomBoom"
        end

        expect(ExceptionHandling).to receive(:log_error).with(instance_of(RuntimeError), /override_with_new_connection: resetting/)

        log_error_message = /Failure establishing database connection using spec: .*"host"=>"10\.0\.0\./
        expect(ExceptionHandling).to receive(:log_error).with(instance_of(RuntimeError), log_error_message).twice

        expect do
          connection_manager.using(access: :balanced) do
            # This should fail
          end
        end.to raise_error("BoomBoom")
      end
    end

    describe "connection_pool_stats" do
      it "should return a hash of stats with zeroes for unused table_sets" do
        configure_ats_like_ringswitch
        ActiveTableSet.enable

        connection_stub = Object.new
        allow(connection_stub).to receive(:query_options) { {} }
        expect(connection_stub).to receive(:query) { }.exactly(3).times
        allow(connection_stub).to receive(:ping) { true }
        allow(connection_stub).to receive(:close).exactly(3).times

        allow(Mysql2::EM::Client).to receive(:new) { |config| connection_stub }

        c0 = ActiveRecord::Base.connection
        fiber1 = Fiber.new { c1 = ActiveRecord::Base.connection; Fiber.yield }
        fiber2 = Fiber.new { c2 = ActiveRecord::Base.connection; Fiber.yield }
        fiber3 = Fiber.new { c3 = ActiveRecord::Base.connection; Fiber.yield }
        fiber1.resume # bump in_use and allocated to 2
        fiber2.resume # bump in_use and allocated to 3
        fiber1.resume # allow fiber to exit (so connection can be reclaimed)
        fiber2.resume #   "      "   "   "    "    "        "   "   "
        fiber3.resume # reset in_use to 2 but allocated will stay at 3

        stats = ActiveTableSet.manager.connection_pool_stats

        expect(stats).to eq(
                           "ringswitch-110" => { allocated: 3, in_use: 2 }
                         )
      end
    end

    describe "reap_connections" do
      it "should call reap_connections on each connection pool" do
        configure_ats_like_ringswitch
        ActiveTableSet.enable

        connection_stub = Object.new
        allow(connection_stub).to receive(:query_options) { {} }
        expect(connection_stub).to receive(:query) { }
        allow(connection_stub).to receive(:ping) { true }
        allow(connection_stub).to receive(:close).exactly(3).times

        allow(Mysql2::EM::Client).to receive(:new) { |config| connection_stub }

        reap_count = 0
        allow_any_instance_of(ActiveTableSet::FiberedDatabaseConnectionPool).to receive(:reap_connections) { reap_count += 1 }

        c0 = ActiveRecord::Base.connection
        c1 = ActiveTableSet.using(timeout: :migration) { ActiveRecord::Base.connection }

        reap_count = 0
        ActiveTableSet.manager.reap_connections

        expect(reap_count).to eq(2)
      end
    end
  end

  context "with a stubbed pool manager and dynamic_host_config" do
    subject { -> { @new_host } }

    let(:connection_pool)    { StubConnectionPool.new }
    let(:connection_handler) { StubConnectionHandler.new }
    let(:connection_manager) do
      allow(ActiveTableSet::Configuration::Partition).to receive(:pid).and_return(1)
      ActiveTableSet::ConnectionManager.new(config: dynamic_host_config, connection_handler: connection_handler)
    end

    it "should call the lambda when host is a proc" do
      TestLog.clear_log
      connection_manager

      expect(
        connection_handler.current_config["host"]
      ).to eq(subject.call)

      ActiveRecord::Base.set_next_client_exception(ArgumentError, "boom-boom")
      @new_host = "192.168.1.1"
      connection_manager.using(access: :balanced) do
        expect(TestLog.logged_lines.second).to match(/boom\-boom/)
        expect(connection_handler.current_config["host"]).to eq(@new_host)
      end
    end

    context "when service discovery raises an error" do
      subject { -> { raise "ConsulFail" } }

      it "should have error handling when the lambda raises" do
        @new_host = "original"

        connection_manager

        expect(
          connection_handler.current_config["host"]
        ).to eq(nil)
      end
    end
  end

  def dynamic_host_config
    ActiveTableSet::Configuration::Config.config do |conf|
      conf.enforce_access_policy true
      conf.environment           'test'
      conf.default = { table_set: :common }

      conf.read_only_username  "read_only_tester"
      conf.read_only_password  "verysecure_too"
      conf.adapter             "stub_client"

      conf.timeout name: :web, timeout: 110.seconds
      conf.timeout name: :batch, timeout: 30.minutes

      conf.table_set do |ts|
        ts.name = :common
        ts.wait_timeout = 28800

        ts.access_policy do |ap|
          ap.disallow_read  'cf_%'
          ap.disallow_write 'cf_%'
        end

        ts.partition do |part|
          part.leader do |leader|
            leader.host subject
            leader.read_write_username "tester"
            leader.read_write_password "verysecure"
            leader.read_only_username "read_only_tester_part"
            leader.read_only_password "verysecure_too_part"
            leader.database "main"
          end

          part.follower do |follower|
            follower.host subject
            follower.read_write_username "tester1"
            follower.read_write_password "verysecure1"
            follower.read_only_username "read_only_tester_follower"
            follower.read_only_password "verysecure_too_follower"
            follower.database  "replication1"
          end

          part.follower do |follower|
            follower.host subject
            follower.read_write_username "tester2"
            follower.read_write_password "verysecure2"
            follower.database "replication2"
          end
        end
      end
    end
  end
end
