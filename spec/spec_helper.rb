# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'active_table_set'
require 'active_record/connection_adapters/mysql2_adapter'
require 'pry'
require 'pry-byebug'
require_relative 'time_stubbing'
require_relative 'log_stubbing'
require_relative 'database_stubbing'


def load_sample_query(name)
  File.read(File.expand_path("../fixtures/sample_queries/#{name}.sql",  __FILE__))
end

def replace_process_settings_with_fixture(new_content_fixture)
  content_source = File.expand_path("./fixtures/process_settings/#{new_content_fixture}.yml", __dir__)
  content_destination = File.expand_path(ProcessSettings::Monitor.file_path)
  `cat #{content_source} > #{content_destination}`
  sleep 1 # we need to allow time for the watcher thread to pick up the change
end

module SpecHelper
  def leader
    { host: "127.0.0.8",  read_write_username: "tester",  read_write_password: "verysecure",  database: "main" }
  end

  def follower1
    { host: "127.0.0.9",  read_write_username: "tester1", read_write_password: "verysecure1", database: "replication1" }
  end

  def follower2
    { host: "127.0.0.10", read_write_username: "tester2", read_write_password: "verysecure2", database: "replication2" }
  end

  def partition_cfg
    { partition_key: 'alpha', leader: leader, followers: [follower1, follower2] }
  end

  def table_set_cfg
    { :name => "test_ts", partitions: [partition_cfg], access_policy: { disallow_read: "cf_%" } }
  end

  def beta_leader
    { host: "10.0.0.1",   read_write_username: "beta",  read_write_password: "verysecure",  database: "main" }
  end

  def beta_follower1
    { host: "10.0.0.2",   read_write_username: "beta1", read_write_password: "verysecure1", database: "replication1" }
  end

  def beta_follower2
    { host: "10.0.0.3",   read_write_username: "beta2", read_write_password: "verysecure2", database: "replication2" }
  end

  def beta_partition_cfg
    { partition_key: 'beta', leader: beta_leader, followers: [beta_follower1, beta_follower2] }
  end

  def multi_table_set_cfg
    { :name => "test_multi", partitions: [partition_cfg, beta_partition_cfg], access_policy: { disallow_read: "cf_%" } }
  end

  def small_table_set
    ActiveTableSet.clear_for_testing
    ActiveTableSet.config do |conf|
      conf.enforce_access_policy true
      conf.environment           'test'
      conf.default  =  { table_set: :common }

      conf.table_set do |ts|
        ts.name = :common
        ts.checkout_timeout = 2

        ts.database "main"

        ts.partition do |part|
          part.leader do |leader|
            leader.host      "10.0.0.1"
            leader.read_write_username  "tester"
            leader.read_write_password  "verysecure"
            leader.read_only_username  "read_only_tester_part"
            leader.read_only_password  "verysecure_too_part"
          end
        end
      end
    end
  end

  def large_table_set
    ActiveTableSet.clear_for_testing
    ActiveTableSet::Configuration::Config.config do |conf|
      conf.enforce_access_policy true
      conf.environment           'test'
      conf.default  =  { table_set: :common }

      conf.read_only_username  "read_only_tester"
      conf.read_only_password  "verysecure_too"
      conf.adapter             "stub_client"

      conf.timeout name: :web, timeout: 110.seconds
      conf.timeout name: :batch, timeout: 30.minutes, net_read_timeout: 30.minutes, net_write_timeout: 1.minute

      conf.table_set do |ts|
        ts.name = :common
        ts.wait_timeout = 28800
        ts.net_read_timeout = 600
        ts.net_write_timeout = 120
        ts.checkout_timeout = 2

        ts.access_policy do |ap|
          ap.disallow_read  'cf_%'
          ap.disallow_write 'cf_%'
        end

        ts.partition do |part|
          part.leader do |leader|
            leader.host      "10.0.0.1"
            leader.read_write_username  "tester"
            leader.read_write_password  "verysecure"
            leader.read_only_username  "read_only_tester_part"
            leader.read_only_password  "verysecure_too_part"
            leader.database  "main"
          end

          part.follower do |follower|
            follower.host      "10.0.0.2"
            follower.read_write_username  "tester1"
            follower.read_write_password  "verysecure1"
            follower.read_only_username  "read_only_tester_follower"
            follower.read_only_password  "verysecure_too_follower"
            follower.database  "replication1"
          end

          part.follower do |follower|
            follower.host      "10.0.0.3"
            follower.read_write_username  "tester2"
            follower.read_write_password  "verysecure2"
            follower.database  "replication2"
          end
        end
      end

      conf.table_set do |ts|
        ts.name = :sharded
        ts.checkout_timeout = 2

        ts.access_policy do |ap|
          ap.allow_write    'cf_%'
        end

        ts.partition do |part|
          part.partition_key 'alpha'
          part.leader do |leader|
            leader.host      "11.0.1.1"
            leader.read_write_username  "tester"
            leader.read_write_password  "verysecure"
            leader.database  "main"
          end

          part.follower do |follower|
            follower.host      "11.0.1.2"
            follower.read_write_username  "tester1"
            follower.read_write_password  "verysecure1"
            follower.database  "replication1"
          end

          part.follower do |follower|
            follower.host      "11.0.1.3"
            follower.read_write_username  "tester2"
            follower.read_write_password  "verysecure2"
            follower.database  "replication2"
          end
        end

        ts.partition do |part|
          part.partition_key 'beta'

          part.leader do |leader|
            leader.host      "11.0.2.1"
            leader.read_write_username  "tester"
            leader.read_write_password  "verysecure"
            leader.database  "main"
          end
        end

        ts.before_enable = -> { Proc.new { "block" } }
      end

      conf.test_scenario do |db|
        db.scenario_name "legacy"
        db.host      "12.0.0.1"
        db.read_write_username  "tester1"
        db.read_write_password  "verysecure1"
        db.database  "replication1"
      end

      conf.test_scenario do |db|
        db.scenario_name "fixture"
        db.host      "12.0.0.2"
        db.read_write_username  "tester1"
        db.read_write_password  "verysecure1"
        db.database  "replication1"
      end
    end
  end

  def configure_ats_like_ringswitch
    ActiveTableSet.clear_for_testing
    ActiveTableSet.config do |conf|
      conf.enforce_access_policy true
      conf.environment           'test'
      conf.default  =  { table_set: :ringswitch }

      conf.table_set do |ts|
        ts.name :ringswitch
        ts.adapter 'fibered_mysql2'
        ts.checkout_timeout = 2
        ts.access_policy do |ap|
          ap.disallow_read  'cf_%'
          ap.disallow_write 'cf_%'
        end
        ts.partition do |part|
          part.leader do |leader|
            leader.host                 "10.0.0.1"
            leader.read_write_username  "tester"
            leader.read_write_password  "verysecure"
            leader.database             "main"
          end
        end
      end

      conf.table_set do |ts|
        ts.name :ringswitch_jobs
        ts.adapter 'fibered_mysql2'
        ts.pool_size 1
        ts.checkout_timeout = 2
        ts.partition do |part|
          part.leader do |leader|
            leader.host                 "10.0.0.1"
            leader.read_write_username  "tester"
            leader.read_write_password  "verysecure"
            leader.database             "main"
          end
        end
      end
    end
  end
end

RSpec.configure do |c|
  c.include SpecHelper
  c.filter_run focus: true
  c.run_all_when_everything_filtered = true
end

ProcessSettings::Monitor.file_path = File.expand_path("./fixtures/process_settings/combined_process_settings.yml", __dir__)
ProcessSettings::Monitor.logger = Logger.new(STDOUT)
