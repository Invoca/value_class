$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'active_table_set'
require 'active_record/connection_adapters/mysql2_adapter'
require 'pry'

###############################################################
#
# Time stubbing
#
###############################################################
class Time
  cattr_reader :now_override

  class << self
    def now_override= override_time
      if ActiveSupport::TimeWithZone === override_time
        override_time = override_time#.localtime
      else
        override_time.nil? || Time === override_time or raise "override_time should be a Time object, but was a #{override_time.class.name}"
      end
      @@now_override = override_time
    end

    unless defined? @@_old_now_defined
      alias old_now now
      @@_old_now_defined = true
    end
  end

  def self.now
    now_override ? now_override.dup : old_now
  end
end


###############################################################
#
# Log stubbing
#
###############################################################
require "exception_handling"

class TestLog
  def self.stream
    @log_stream ||= StringIO.new
  end

  def self.logged_lines
    @log_stream.rewind
    lines = @log_stream.readlines
    clear_log
    lines.map { |l| l.strip }.reject { |l| l == "" }.compact
  end

  def self.clear_log
    @log_stream.reopen
  end
end

# required
ExceptionHandling.server_name             = "test"
ExceptionHandling.sender_address          = %("Exceptions" <exceptions@example.com>)
ExceptionHandling.exception_recipients    = ['exceptions@example.com']
ExceptionHandling.logger                  = Logger.new(TestLog.stream)



module Rails
  def self.env
    'test'
  end
end

###############################################################
#
# Database stubbing
#
###############################################################
class StubClient < ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter
  attr_reader :called_commands, :config
  attr_accessor :reconnect, :connect_timeout, :read_timeout, :write_timeout, :local_infile, :charset_name
  attr_accessor :query_options, :active
  attr_accessor :pool

  def initialize(config = {})
    @config = config
    @query_options = Mysql2::Client.default_query_options.dup
    @query_options.merge!(config)
    @active = true
    clear_commands
  end

  def record_command(command, args)
    @called_commands << [command, args]
  end

  def clear_commands
    @called_commands = []
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

  def active?
    record_command(:active?, [])
    active
  end

  def lease
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

_ = ActiveRecord::Base
class ActiveRecord::Base
  def self.set_next_client_exception(exception, message)
    @next_client_exception = [exception, message]
  end

  def self.stub_client_connection(config)
    if exception = @next_client_exception
      @next_client_exception = nil
      raise exception.first, exception.last
    else
      StubClient.new(config)
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
    self.stub_client ||= StubClient.new(@config)
  end

  def release_connection
  end
end

class StubConnectionHandler
  prepend ActiveTableSet::Extensions::ConnectionHandlerExtension

  attr_reader :connection_pools, :class_to_pool

  def initialize(pools = {})
    @connection_pools = pools
    @class_to_pool    = {}
  end


  def retrieve_connection_pool(klass)
    @class_to_pool[klass.name]
  end

  def retrieve_connection(klass)
    StubClient.new(current_config)
  end

  def retrieve_connection(klass) #:nodoc:
    pool = retrieve_connection_pool(klass)
    raise ConnectionNotEstablished, "No connection pool for #{klass}" unless pool
    conn = pool.connection
    raise ConnectionNotEstablished, "No connection for #{klass} in connection pool" unless conn
    conn
  end


  def connection
    retrieve_connection(ActiveRecord::Base)
  end

  def current_config
    retrieve_connection_pool(ActiveRecord::Base).spec.config
  end
end


def load_sample_query(name)
  File.read(File.expand_path("../fixtures/sample_queries/#{name}.sql",  __FILE__))
end


module SpecHelper
  def leader
    { :host => "127.0.0.8",  :read_write_username => "tester",  :read_write_password => "verysecure",  :database => "main" }
  end

  def follower1
    { :host => "127.0.0.9",  :read_write_username => "tester1", :read_write_password => "verysecure1", :database => "replication1" }
  end

  def follower2
    { :host => "127.0.0.10", :read_write_username => "tester2", :read_write_password => "verysecure2", :database => "replication2" }
  end

  def partition_cfg
    { :partition_key => 'alpha', :leader => leader, :followers => [follower1, follower2] }
  end

  def table_set_cfg
    { :name => "test_ts", :partitions => [partition_cfg], :access_policy => { :disallow_read => "cf_%" } }
  end

  def beta_leader
    { :host => "10.0.0.1",   :read_write_username => "beta",  :read_write_password => "verysecure",  :database => "main" }
  end

  def beta_follower1
    { :host => "10.0.0.2",   :read_write_username => "beta1", :read_write_password => "verysecure1", :database => "replication1" }
  end

  def beta_follower2
    { :host => "10.0.0.3",   :read_write_username => "beta2", :read_write_password => "verysecure2", :database => "replication2" }
  end

  def beta_partition_cfg
    { :partition_key => 'beta', :leader => beta_leader, :followers => [beta_follower1, beta_follower2] }
  end

  def multi_table_set_cfg
    { :name => "test_multi", :partitions => [partition_cfg, beta_partition_cfg], :access_policy => { :disallow_read => "cf_%" } }
  end

  def small_table_set
    ActiveTableSet::Configuration::Config.config do |conf|
      conf.enforce_access_policy true
      conf.environment           'test'
      conf.default  =  { table_set: :common }

      conf.table_set do |ts|
        ts.name = :common

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
    ActiveTableSet::Configuration::Config.config do |conf|
      conf.enforce_access_policy true
      conf.environment           'test'
      conf.default  =  { table_set: :common }

      conf.read_only_username  "read_only_tester"
      conf.read_only_password  "verysecure_too"
      conf.adapter             "stub_client"

      conf.timeout name: :web, timeout: 110.seconds
      conf.timeout name: :batch, timeout: 30.minutes

      conf.table_set do |ts|
        ts.name = :common

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
end

RSpec.configure do |c|
  c.include SpecHelper
end