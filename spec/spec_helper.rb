$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'active_table_set'
require 'pry'

class StubClient
  attr_accessor :reconnect, :connect_timeout, :read_timeout, :write_timeout, :local_infile, :charset_name
  attr_accessor :query_options

  def initialize(config)
    @config = config
    @called_commands = []
    @query_options = Mysql2::Client.default_query_options.dup
    @query_options.merge! config
  end

  def record_command(command, args)
    @called_commands << [ command, args]
  end

  def query(sql, options = {})
    record_command(:query, [sql, options])
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
    :encoding, :initialize_ext
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
    self.connection =StubClient.new(@config)
    configure_connection
  end
end

def load_sample_query(name)
  File.read(File.expand_path("../fixtures/sample_queries/#{name}.sql",  __FILE__))
end
