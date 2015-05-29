$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'active_table_set'
require 'pry'

module Rails
  def self.env
    'test'
  end
end

class StubClient
  attr_reader :called_commands, :config
  attr_accessor :reconnect, :connect_timeout, :read_timeout, :write_timeout, :local_infile, :charset_name
  attr_accessor :query_options

  def initialize(config = {})
    @config = config
    @called_commands = []
    @query_options = Mysql2::Client.default_query_options.dup
    @query_options.merge! config
  end

  def record_command(command, args)
    @called_commands << [command, args]
  end

  def query(sql, options = {})
    record_command(:query, [sql, options])
  end

  def escape(string)
    Mysql2::Client.escape(string)
  end

  def self.escape(string)
    Mysql2::Client.escape(string)
  end

  def ssl_set(p1, p2, p3, p4, p5)
    record_command(:ssl_set, [p1, p2, p3, p4, p5])
  end

  def connect(p1, p2, p3, p4, p5, p6, p7)
    record_command(:connect, [p1, p2, p3, p4, p5, p6, p7])
  end


  DEFAULT = { args: 0, default_return: nil }

  SIMPLE_METHODS = [ :close, :abandon_results!, :info, :server_info, :socket, :async_result, :last_id, :affected_rows,
                     :thread_id, :ping, :select_db, :more_results?, :next_result, :store_result, :warning_count, :query_info_string,
                     :encoding, :initialize_ext, :clear_cache!, :schema_cache
  ]

  SIMPLE_METHODS.each do |method|
    define_method method do
      record_command(method, [])
    end
  end
end

class StubDbAdaptor < ActiveRecord::ConnectionAdapters::Mysql2Adapter
  SAMPLE_CONFIG = {
      host: 'localhost',
      username: 'dev',
      password: 'changeme',
      database: 'app',
      port: 3306,
      socket: nil
  }

  def self.stub_db_connection(config = SAMPLE_CONFIG)
    config[:username] = 'root' if config[:username].nil?
    client = StubClient.new(config.symbolize_keys)
    options = [config[:host], config[:username], config[:password], config[:database], config[:port], config[:socket], 0]
    StubDbAdaptor.new(client, nil, options, config)
  end

  def connect
    self.connection = StubClient.new(@config)
    configure_connection
  end
end

class StubConnectionPool
  attr_accessor :stub_client

  def initialize(config = {})
    @config = config
  end

  def connection
    stub_client || StubClient.new(@config)
  end

  def release_connection
  end
end

class PoolManagerStub
  attr_accessor :responses
  attr_reader :pool_requests
  attr_accessor :stub_pool

  def initialize
    @pool_requests = []
    @responses = []
  end

  def get_pool(key:)
    @pool_requests << key
    @stub_pool || StubConnectionPool.new(key.specification)
  end
end


def load_sample_query(name)
  File.read(File.expand_path("../fixtures/sample_queries/#{name}.sql",  __FILE__))
end


module SpecHelper
  def leader
    { :host => "127.0.0.8",  :username => "tester",  :password => "verysecure",  :timeout => 2, :database => "main" }
  end

  def follower1
    { :host => "127.0.0.9",  :username => "tester1", :password => "verysecure1", :timeout => 2, :database => "replication1" }
  end

  def follower2
    { :host => "127.0.0.10", :username => "tester2", :password => "verysecure2", :timeout => 2, :database => "replication2" }
  end

  def partition_cfg
    { :partition_key => 'alpha', :leader => leader, :followers => [follower1, follower2] }
  end

  def table_set_cfg
    { :name => "test_ts", :partitions => [partition_cfg], :access_policy => { :disallow_read => "cf_%" } }
  end

  def beta_leader
    { :host => "10.0.0.1",   :username => "beta",  :password => "verysecure",  :timeout => 2, :database => "main" }
  end

  def beta_follower1
    { :host => "10.0.0.2",   :username => "beta1", :password => "verysecure1", :timeout => 2, :database => "replication1" }
  end

  def beta_follower2
    { :host => "10.0.0.3",   :username => "beta2", :password => "verysecure2", :timeout => 2, :database => "replication2" }
  end

  def beta_partition_cfg
    { :partition_key => 'beta', :leader => beta_leader, :followers => [beta_follower1, beta_follower2] }
  end

  def multi_table_set_cfg
    { :name => "test_multi", :partitions => [partition_cfg, beta_partition_cfg], :access_policy => { :disallow_read => "cf_%" } }
  end

  def large_table_set
    ActiveTableSet::Configuration::Config.config do |conf|
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
            leader.host      "10.0.0.1"
            leader.username  "tester"
            leader.password  "verysecure"
            leader.timeout   2
            leader.database  "main"
          end

          part.follower do |follower|
            follower.host      "10.0.0.2"
            follower.username  "tester1"
            follower.password  "verysecure1"
            follower.timeout   2
            follower.database  "replication1"
          end

          part.follower do |follower|
            follower.host      "10.0.0.3"
            follower.username  "tester2"
            follower.password  "verysecure2"
            follower.timeout   2
            follower.database  "replication2"
          end
        end
      end

      conf.table_set do |ts|
        ts.name = :sharded

        ts.access_policy do |ap|
          ap.allow_write    'cf_%'
        end

        ts.partition do |part|
          part.partition_key 'alpha'
          part.leader do |leader|
            leader.host      "11.0.1.1"
            leader.username  "tester"
            leader.password  "verysecure"
            leader.timeout   2
            leader.database  "main"
          end

          part.follower do |follower|
            follower.host      "11.0.1.2"
            follower.username  "tester1"
            follower.password  "verysecure1"
            follower.timeout   2
            follower.database  "replication1"
          end

          part.follower do |follower|
            follower.host      "11.0.1.3"
            follower.username  "tester2"
            follower.password  "verysecure2"
            follower.timeout   2
            follower.database  "replication2"
          end
        end

        ts.partition do |part|
          part.partition_key 'beta'

          part.leader do |leader|
            leader.host      "11.0.2.1"
            leader.username  "tester"
            leader.password  "verysecure"
            leader.timeout   2
            leader.database  "main"
          end

          part.follower do |follower|
            follower.host      "11.0.2.2"
            follower.username  "tester1"
            follower.password  "verysecure1"
            follower.timeout   2
            follower.database  "replication1"
          end

          part.follower do |follower|
            follower.host      "11.0.2.3"
            follower.username  "tester2"
            follower.password  "verysecure2"
            follower.timeout   2
            follower.database  "replication2"
          end
        end
      end

      conf.test_scenario do |db|
        db.scenario_name "legacy"
        db.host      "12.0.0.1"
        db.username  "tester1"
        db.password  "verysecure1"
        db.timeout   2
        db.database  "replication1"
      end

      conf.test_scenario do |db|
        db.scenario_name "fixture"
        db.host      "12.0.0.2"
        db.username  "tester1"
        db.password  "verysecure1"
        db.timeout   2
        db.database  "replication1"
      end
    end
  end
end

RSpec.configure do |c|
  c.include SpecHelper
end