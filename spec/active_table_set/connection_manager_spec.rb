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

      it "resets connections if exceptions happen" do
        connection_manager
        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")

        connection_manager.using(table_set: :sharded, partition_key: "alpha") do
          expect(connection_handler.current_config["host"]).to eq("11.0.1.1")

          begin
            connection_manager.using(table_set: :common) do
              raise ArgumentError, "boom"
            end
            fail "Exception did not propagate"
          rescue ArgumentError
          end

          expect(connection_handler.current_config["host"]).to eq("11.0.1.1")
        end

        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
      end

      it "resets even multiple levels of nesting if exceptions occur" do
        connection_manager
        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")

        begin
          connection_manager.using(table_set: :sharded, partition_key: "alpha") do
            expect(connection_handler.current_config["host"]).to eq("11.0.1.1")
            connection_manager.using(table_set: :common) do
              raise ArgumentError, "boom"
            end

            fail "Exception did not propagate"
          end
        rescue ArgumentError
        end

        expect(connection_handler.current_config["host"]).to eq("10.0.0.1")
      end
    end

    context "use_test_scenario" do
      it "overrides the access policy, but not the connection" do
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

            connection_manager.allow_test_access do
              expect(connection_manager.access_policy).to eq(nil)
            end
          end

          expect(connection_handler.current_config["host"]).to eq("12.0.0.1")
          expect(connection_manager.access_policy.disallow_read).to eq("")
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
          expect(TestLog.logged_lines.first).to match(/badaboom/)
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
    end
  end
end
