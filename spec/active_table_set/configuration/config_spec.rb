require 'spec_helper'

describe ActiveTableSet::Configuration::Config do
  it "can be constructed using a block" do
    ats_config = ActiveTableSet::Configuration::Config.config do |conf|
      conf.enforce_access_policy true
      conf.environment           'test'
      conf.default_connection  =  { table_set: :common }

      conf.table_set do |ts|
        ts.name = :common

        ts.access_policy do |ap|
          ap.disallow_read  'cf_%'
          ap.disallow_write 'cf_%'
        end

        ts.partition do |part|
          part.leader do |leader|
            leader.host                 "127.0.0.8"
            leader.read_write_username  "tester"
            leader.read_write_password  "verysecure"
            leader.timeout              2
            leader.database             "main"
          end

          part.follower do |follower|
            follower.host                 "127.0.0.9"
            follower.read_write_username  "tester1"
            follower.read_write_password  "verysecure1"
            follower.timeout              2
            follower.database             "replication1"
          end

          part.follower do |follower|
            follower.host      "127.0.0.10"
            follower.read_write_username  "tester2"
            follower.read_write_password  "verysecure2"
            follower.timeout   2
            follower.database  "replication2"
          end
        end
      end
    end

    expect(ats_config.table_sets.size).to eq(1)
    expect(ats_config.enforce_access_policy).to eq(true)
  end

  it "allows test scenarios to be specified" do
    ats_config = ActiveTableSet::Configuration::Config.config do |conf|
      conf.enforce_access_policy true
      conf.environment           'test'
      conf.default_connection  =  { table_set: :common }

      conf.table_set do |ts|
        ts.name = :common

        ts.access_policy do |ap|
          ap.disallow_read  'cf_%'
          ap.disallow_write 'cf_%'
        end

        ts.partition do |part|
          part.leader do |leader|
            leader.host      "127.0.0.8"
            leader.read_write_username  "tester"
            leader.read_write_password  "verysecure"
            leader.timeout   2
            leader.database  "main"
          end
        end
      end

      conf.test_scenario do |ts|
        ts.scenario_name "legacy"
        ts.host      "127.0.0.8"
        ts.read_write_username  "tester"
        ts.read_write_password  "verysecure"
        ts.timeout   2
        ts.database  "main"
      end

      conf.test_scenario do |ts|
        ts.scenario_name "adwords"
        ts.host      "127.0.0.8"
        ts.read_write_username  "tester"
        ts.read_write_password  "verysecure"
        ts.timeout   2
        ts.database  "main"
      end
    end

    expect(ats_config.test_scenarios.size).to eq(2)
    expect(ats_config.test_scenarios.first.scenario_name).to eq("legacy")
  end

  it "raises if no table set was specified" do
    expect { ActiveTableSet::Configuration::Config.new(default_connection:{table_set: :common}) }.to raise_error(ArgumentError, "no table sets defined")
  end

  it "raises if a default connection setting is not specified" do
    expect { ActiveTableSet::Configuration::Config.new(table_sets: [table_set_cfg]) }.to raise_error(ArgumentError, "must provide a value for default_connection")
  end

  context "connection_spec" do
    it "finds common connections" do
      using_spec = ActiveTableSet::Configuration::UsingSpec.new(
          table_set: :common,
          access_mode: :write,
          partition_key: nil,
          test_scenario: nil,
          timeout: 100 )

      con_spec = large_table_set.connection_spec(using_spec)

      expect(con_spec.specification.host).to eq("10.0.0.1")
    end

    it "finds sharded connections" do
      using_spec = ActiveTableSet::Configuration::UsingSpec.new(
          table_set: :sharded,
          access_mode: :write,
          partition_key: "alpha",
          test_scenario: nil,
          timeout: 100 )

      con_spec = large_table_set.connection_spec(using_spec)

      expect(con_spec.specification.host).to eq("11.0.1.1")
    end


    it "raises if the table set is not found" do
      using_spec = ActiveTableSet::Configuration::UsingSpec.new(
          table_set: :not_found,
          access_mode: :write,
          partition_key: "alpha",
          test_scenario: nil,
          timeout: 100 )

      expect { large_table_set.connection_spec(using_spec) }.to raise_error(ArgumentError, "Unknown table set not_found, available_table_sets: common, sharded")
    end

    # TODO
    # it "returns the test scenario if it is overridden" do
    #   db_config = large_table_set.database_config(
    #       table_set: :sharded,
    #       access_mode: :write,
    #       partition_key: "alpha",
    #       test_scenario: "legacy" )
    #
    #   expect(db_config.host).to eq("12.0.0.1")
    # end
    #
    # it "raises if the test scenario is not found" do
    #   expect { large_table_set.database_config(
    #       table_set: :common,
    #       access_mode: :write,
    #       partition_key: nil,
    #       test_scenario: "badname") }.to raise_error(ArgumentError, "Unknown test scenario badname, available_table_sets: fixture, legacy" )
    # end

  end

  context "database_configuration" do
    it "can report all database confgurations from table sets" do
      database_configurations = large_table_set.database_configuration

      expected = {
          "test"                          => {"host"=>"10.0.0.1", "database"=>"main",         "username"=>"tester",  "password"=>"verysecure",  "connect_timeout"=>5, "read_timeout"=>110, "write_timeout"=>110, "encoding"=>"utf8", "collation"=>"utf8_general_ci", "adapter"=>"mysql2", "pool"=>5, "reconnect"=>true},
          "test_common_leader"            => {"host"=>"10.0.0.1", "database"=>"main",         "username"=>"tester",  "password"=>"verysecure",  "connect_timeout"=>5, "read_timeout"=>110, "write_timeout"=>110, "encoding"=>"utf8", "collation"=>"utf8_general_ci", "adapter"=>"mysql2", "pool"=>5, "reconnect"=>true},
          "test_common_follower_0"        => {"host"=>"10.0.0.2", "database"=>"replication1", "username"=>"tester1", "password"=>"verysecure1", "connect_timeout"=>5, "read_timeout"=>110, "write_timeout"=>110, "encoding"=>"utf8", "collation"=>"utf8_general_ci", "adapter"=>"mysql2", "pool"=>5, "reconnect"=>true},
          "test_common_follower_1"        => {"host"=>"10.0.0.3", "database"=>"replication2", "username"=>"tester2", "password"=>"verysecure2", "connect_timeout"=>5, "read_timeout"=>110, "write_timeout"=>110, "encoding"=>"utf8", "collation"=>"utf8_general_ci", "adapter"=>"mysql2", "pool"=>5, "reconnect"=>true},
          "test_sharded_alpha_leader"     => {"host"=>"11.0.1.1", "database"=>"main",         "username"=>"tester",  "password"=>"verysecure",  "connect_timeout"=>5, "read_timeout"=>110, "write_timeout"=>110, "encoding"=>"utf8", "collation"=>"utf8_general_ci", "adapter"=>"mysql2", "pool"=>5, "reconnect"=>true},
          "test_sharded_alpha_follower_0" => {"host"=>"11.0.1.2", "database"=>"replication1", "username"=>"tester1", "password"=>"verysecure1", "connect_timeout"=>5, "read_timeout"=>110, "write_timeout"=>110, "encoding"=>"utf8", "collation"=>"utf8_general_ci", "adapter"=>"mysql2", "pool"=>5, "reconnect"=>true},
          "test_sharded_alpha_follower_1" => {"host"=>"11.0.1.3", "database"=>"replication2", "username"=>"tester2", "password"=>"verysecure2", "connect_timeout"=>5, "read_timeout"=>110, "write_timeout"=>110, "encoding"=>"utf8", "collation"=>"utf8_general_ci", "adapter"=>"mysql2", "pool"=>5, "reconnect"=>true},
          "test_sharded_beta_leader"      => {"host"=>"11.0.2.1", "database"=>"main",         "username"=>"tester",  "password"=>"verysecure",  "connect_timeout"=>5, "read_timeout"=>110, "write_timeout"=>110, "encoding"=>"utf8", "collation"=>"utf8_general_ci", "adapter"=>"mysql2", "pool"=>5, "reconnect"=>true},
          "test_test_scenario_fixture"    => {"host"=>"12.0.0.2", "database"=>"replication1", "username"=>"tester1", "password"=>"verysecure1", "connect_timeout"=>5, "read_timeout"=>110, "write_timeout"=>110, "encoding"=>"utf8", "collation"=>"utf8_general_ci", "adapter"=>"mysql2", "pool"=>5, "reconnect"=>true},
          "test_test_scenario_legacy"     => {"host"=>"12.0.0.1", "database"=>"replication1", "username"=>"tester1", "password"=>"verysecure1", "connect_timeout"=>5, "read_timeout"=>110, "write_timeout"=>110, "encoding"=>"utf8", "collation"=>"utf8_general_ci", "adapter"=>"mysql2", "pool"=>5, "reconnect"=>true}
      }
      expect(database_configurations).to eq(expected)
    end
  end

  context "convenience" do
    it "database attributes to be specified at every level" do
      ats_config = ActiveTableSet::Configuration::Config.config do |conf|
        conf.enforce_access_policy true
        conf.environment           'test'
        conf.default_connection  =  { table_set: :common }

        conf.host "13.0.0.1"

        conf.table_set do |ts|
          ts.name = :common

          ts.access_policy do |ap|
            ap.disallow_read  'cf_%'
            ap.disallow_write 'cf_%'
          end

          ts.partition do |part|
            part.leader do |leader|
              leader.host      "127.0.0.8"
              leader.read_write_username  "tester"
              leader.read_write_password  "verysecure"
              leader.timeout   2
              leader.database  "main"
            end
          end
        end

        conf.test_scenario do |ts|
          ts.scenario_name "legacy"
          ts.host      "127.0.0.8"
          ts.read_write_username  "tester"
          ts.read_write_password  "verysecure"
          ts.timeout   2
          ts.database  "main"
        end

        conf.test_scenario do |ts|
          ts.scenario_name "adwords"
          ts.read_write_username  "tester"
          ts.read_write_password  "verysecure"
          ts.timeout   2
          ts.database  "main"
        end
      end
    end

  end
end
