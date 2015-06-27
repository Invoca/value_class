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

  attr_reader :connection_pools, :class_to_pool, :remove_calls

  def initialize(pools = {})
    @connection_pools = pools
    @class_to_pool    = {}
    @remove_calls     = []
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

  def remove_connection(klass)
    remove_calls << klass.name
  end
end
