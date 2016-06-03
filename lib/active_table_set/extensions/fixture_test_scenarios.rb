require 'shellwords'

module ActiveRecord
  module TestFixturesExtension
    FIXTURE_REALMS = [:default, :sample_data]

    @@active_fixture ||= :none
    @@current_fixture_realm = :default

    def setup_fixtures
      return unless !ActiveRecord::Base.configurations.blank?

      if pre_loaded_fixtures && !use_transactional_fixtures
        raise RuntimeError, 'pre_loaded_fixtures requires use_transactional_fixtures'
      end

      @fixture_cache = {}
      @fixture_connections = []
      @@already_loaded_fixtures ||= {}

      if @@current_fixture_realm != fixture_realm
        @@current_fixture_realm = fixture_realm
        ats_connect(@@current_fixture_realm)
      end

      if !@@already_loaded_fixtures[self.class].nil?
        @loaded_fixtures = @@already_loaded_fixtures[self.class]
      else
        ActiveRecord::Fixtures.reset_cache
        @loaded_fixtures ||= (marshal_hash || create_fixtures_from_yaml)
        @@already_loaded_fixtures[self.class] = @loaded_fixtures
      end

      if run_in_transaction?
        @fixture_connections = ats_fixture_connections
        @fixture_connections.each do |connection|
          connection.increment_open_transactions
          connection.transaction_joinable = false
          connection.begin_db_transaction
        end
      else
        @@already_loaded_fixtures[self.class] = {}
      end

      # Instantiate fixtures for every test if requested.
      instantiate_fixtures if use_instantiated_fixtures
    end

    def create_fixtures_from_yaml
      fixtures = Fixtures.create_fixtures(fixture_path, fixture_table_names, fixture_class_names)
      Hash[fixtures.map { |f| [f.name, f] }]
    end

    def marshal_hash
      begin
        marshal_hash = {}
        marshal_load = Marshal.load(File.read("#{fixture_path}default.marshal"))
        marshal_load.each do |yaml_file, (klass, fixtures)|
          fixture_hash = {}
          fixtures.each do |fixture_sym, id|
            fixture_hash[fixture_sym] = Fixture.new({"id" => id}, klass._?.constantize) if klass.nil? || Object.const_defined?(klass)
          end
          marshal_hash[yaml_file] = fixture_hash
        end
        marshal_hash
      rescue Exception => ex
        puts "Error loading Marshal file #{fixture_path}default.marshal: #{ex}"
        nil
      end
    end


    def ats_connect(fixture)
      ActiveTableSet.use_test_scenario("test_#{fixture}")
      ActiveRecord::Base.connection
    end

    def ats_fixture_connections
      [ActiveRecord::Base.connection]
    end

    def load_fixtures
      Fixtures::FIXTURE_REALMS.each do |fixture_name|
        ats_connect(fixture_name)
        dump_file_name = "#{fixture_path}/#{fixture_name}.sql"
        File.exists?(dump_file_name) or raise "load_fixtures: Could not find #{dump_file_name}"
        load_mysql_dump(dump_file_name)
      end
    end

    # TODO - This could be passed a connection.
    # TODO - This should be a method on test_scenario
    def load_mysql_dump(dump_filename)
      raise "Cannot be used in production!" if Rails.env == 'production'
      # TODO - better to get the config from ATS.
      config = ActiveRecord::Base.connection.instance_eval('@config')
      dump_cmd = "mysql --user=#{Shellwords.shellescape(config[:username])} --password=#{Shellwords.shellescape(config[:password])} #{Shellwords.shellescape(config[:database])} < #{Shellwords.shellescape(dump_filename)}"
      system(dump_cmd) or raise("Loading mysql dump failed: #{dump_cmd.inspect} resulted in an error")
      nil
    end

    # for pre_loaded_fixtures, only require the classes once. huge speed improvement
    @@required_fixture_classes = false

    def instantiate_fixtures
      if pre_loaded_fixtures
        raise RuntimeError, 'Load fixtures before instantiating them.' if ActiveRecord::Fixtures.all_loaded_fixtures.empty?
        unless @@required_fixture_classes
          self.class.require_fixture_classes ActiveRecord::Fixtures.all_loaded_fixtures.keys
          @@required_fixture_classes = true
        end
        ActiveRecord::Fixtures.instantiate_all_loaded_fixtures(self, load_instances?)
      else
        raise RuntimeError, 'Load fixtures before instantiating them.' if @loaded_fixtures.nil?
        @loaded_fixtures.each_value do |fixture_set|
          ActiveRecord::Fixtures.instantiate_fixtures(self, fixture_set, load_instances?)
        end
      end
    end
  end
end
