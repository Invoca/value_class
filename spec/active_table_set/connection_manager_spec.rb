require 'spec_helper'

describe ActiveTableSet::ConnectionManager do
  context "construction" do
    it "raises on missing config parameters" do
      expect { ActiveTableSet::ConnectionManager.new }.to raise_error(ArgumentError, "missing keywords: config, pool_manager")
    end
  end

  context "with a stubbed pool manager" do
    let(:connection_manager) do
      allow(ActiveTableSet::Configuration::Partition).to receive(:pid).and_return(1)
      ActiveTableSet::ConnectionManager.new(config: large_table_set, pool_manager: StubPoolManager.new )
    end

    it "provides a default connection" do
      expect(connection_manager.connection.config.host).to eq("10.0.0.1")
    end

    context "using" do
      it "allows timeouts to be overidden" do
        expect(connection_manager.connection.config.host).to eq("10.0.0.1")
        expect(connection_manager.connection.config.read_timeout).to eq(110)
        expect(connection_manager.connection.config.write_timeout).to eq(110)

        connection_manager.using(timeout: 30) do
          expect(connection_manager.connection.config.host).to eq("10.0.0.1")
          expect(connection_manager.connection.config.read_timeout).to eq(30)
          expect(connection_manager.connection.config.write_timeout).to eq(30)
        end

        expect(connection_manager.connection.config.host).to eq("10.0.0.1")
        expect(connection_manager.connection.config.read_timeout).to eq(110)
        expect(connection_manager.connection.config.write_timeout).to eq(110)
      end

      it "allows connections to different table sets" do
        expect(connection_manager.connection.config.host).to eq("10.0.0.1")

        connection_manager.using(table_set: :sharded, partition_key: "alpha") do
          expect(connection_manager.connection.config.host).to eq("11.0.1.1")
        end

        expect(connection_manager.connection.config.host).to eq("10.0.0.1")
      end

      it "supports nesting, and clears partition key when table set changes" do
        expect(connection_manager.connection.config.host).to eq("10.0.0.1")

        connection_manager.using(table_set: :sharded, partition_key: "alpha") do
          expect(connection_manager.connection.config.host).to eq("11.0.1.1")

          connection_manager.using(table_set: :common) do
            expect(connection_manager.connection.config.host).to eq("10.0.0.1")
          end

          expect(connection_manager.connection.config.host).to eq("11.0.1.1")
        end

        expect(connection_manager.connection.config.host).to eq("10.0.0.1")
      end

      it "allows balanced connections" do
        expect(connection_manager.connection.config.host).to eq("10.0.0.1")
        expect(connection_manager.connection.config.username).to eq("tester")
        expect(connection_manager.connection.config.password).to eq("verysecure")

        connection_manager.using(access: :balanced) do
          expect(connection_manager.connection.config.host).to eq("10.0.0.2")
          expect(connection_manager.connection.config.username).to eq("read_only_tester_follower")
          expect(connection_manager.connection.config.password).to eq("verysecure_too_follower")
        end

        expect(connection_manager.connection.config.username).to eq("tester")
        expect(connection_manager.connection.config.password).to eq("verysecure")
      end

      it "adds the using method to the connection class" do
        connection = connection_manager.connection
        expect(connection.respond_to?(:using)).to eq(true)

        @called_block = false
        expect(ActiveTableSet).to receive(:using).with(table_set: :ts, access: :am, partition_key: :pk, timeout: :t).and_yield
        connection.using(table_set: :ts, access: :am, partition_key: :pk, timeout: :t) do
          @called_block = true
        end

        expect(@called_block).to eq(true)
      end

      it "resets connections if exceptions happen" do
        expect(connection_manager.connection.config.host).to eq("10.0.0.1")

        connection_manager.using(table_set: :sharded, partition_key: "alpha") do
          expect(connection_manager.connection.config.host).to eq("11.0.1.1")

          begin
            connection_manager.using(table_set: :common) do
              raise ArgumentError, "boom"
            end
            fail "Exception did not propagate"
          rescue ArgumentError
          end

          expect(connection_manager.connection.config.host).to eq("11.0.1.1")
        end

        expect(connection_manager.connection.config.host).to eq("10.0.0.1")
      end

      it "resets even multiple levels of nesting if exceptions occur" do
        expect(connection_manager.connection.config.host).to eq("10.0.0.1")

        begin
          connection_manager.using(table_set: :sharded, partition_key: "alpha") do
            expect(connection_manager.connection.config.host).to eq("11.0.1.1")
            connection_manager.using(table_set: :common) do
              raise ArgumentError, "boom"
            end

            fail "Exception did not propagate"
          end
        rescue ArgumentError
        end

        expect(connection_manager.connection.config.host).to eq("10.0.0.1")
      end

      it "raises connection not established if getting a connection from a pool fails" do
        expect(connection_manager.connection.config.host).to eq("10.0.0.1")

        begin
          connection_manager.using(table_set: :sharded, partition_key: "alpha") do
            pool_manager = connection_manager.instance_eval("@pool_manager")
            expect(pool_manager).to receive(:get_pool) { nil }
            connection_manager.using(table_set: :sharded, partition_key: "beta") do
              fail "did not receive exception"
            end
          end
          fail "did not receieve exception"
        rescue ActiveRecord::ConnectionNotEstablished
        end

        expect(connection_manager.connection.config.host).to eq("10.0.0.1")
      end

      it "adds the access policy to the class" do
        connection = connection_manager.connection
        expect(connection.respond_to?(:access_policy)).to eq(true)

        expect(connection.access_policy.disallow_read).to eq("cf_%")
      end

      it "does not change the connection if the parameters are the same" do
        connection_object_id = connection_manager.connection.object_id

        connection_manager.using(access: :leader) do
          expect(connection_manager.connection.object_id).to eq(connection_object_id)
        end
        expect(connection_manager.connection.object_id).to eq(connection_object_id)
      end
    end

    context "use_test_scenario" do
      it "overrides the access policy, but not the connection" do
        expect(connection_manager.connection.config.host).to eq("10.0.0.1")

        connection_manager.use_test_scenario("legacy")
        connection_object_id = connection_manager.connection.object_id
        expect(connection_manager.connection.access_policy.disallow_read).to eq("cf_%")

        expect(connection_manager.connection.config.host).to eq("12.0.0.1")

        connection_manager.using(table_set: :sharded, partition_key: "alpha") do
          expect(connection_manager.connection.config.host).to eq("12.0.0.1")
          expect(connection_manager.connection.object_id).to eq(connection_object_id)
          expect(connection_manager.connection.access_policy.disallow_read).to eq("")

          connection_manager.using(table_set: :common) do
            expect(connection_manager.connection.config.host).to eq("12.0.0.1")
            expect(connection_manager.connection.object_id).to eq(connection_object_id)
            expect(connection_manager.connection.access_policy.disallow_read).to eq("cf_%")
          end

          expect(connection_manager.connection.config.host).to eq("12.0.0.1")
          expect(connection_manager.connection.object_id).to eq(connection_object_id)
          expect(connection_manager.connection.access_policy.disallow_read).to eq("")
        end

        expect(connection_manager.connection.config.host).to eq("12.0.0.1")
        expect(connection_manager.connection.object_id).to eq(connection_object_id)
        expect(connection_manager.connection.access_policy.disallow_read).to eq("cf_%")
      end
    end

    it "supports different settings for different threads" do
      @thread_initial_host = nil
      @thread_shard_host = nil
      @thread_nested_host = nil

      expect(connection_manager.connection.config.host).to eq("10.0.0.1")
      connection_manager.using(table_set: :sharded, partition_key: "alpha") do
        expect(connection_manager.connection.config.host).to eq("11.0.1.1")

        t = Thread.new do
          @thread_initial_host = connection_manager.connection.config.host
          connection_manager.using(table_set: :sharded, partition_key: "beta") do
            @thread_shard_host = connection_manager.connection.config.host
          end
        end
        t.join

        expect(connection_manager.connection.config.host).to eq("11.0.1.1")
      end

      expect(connection_manager.connection.config.host).to eq("10.0.0.1")

      expect(@thread_initial_host).to eq("10.0.0.1")
      expect(@thread_shard_host).to   eq("11.0.2.1")
    end
  end
end
