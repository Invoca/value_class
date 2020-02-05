# ActiveTableSet

ActiveTableSet provides multi-database support through table-set based pool management and access rights enforcement.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_table_set'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install active_table_set

## Usage

To use ActiveTableSet:
 - include the Gemfile in your Rails project and run "bundle install"
 - in your application.rb file add the line "require 'active_table_set/connection_override'"
 - in your config/initializers directory add a file "default_config_loader.rb". 
 
 You will then want to over-ride one of the methods in DefaultConfigLoader. For example, if your situation is straightforward enough to just load 
 from a YAML file, simply override the ats_config_file method to return the appropriate path:

```ruby
module ActiveTableSet
  class DefaultConfigLoader
    def ats_config_file
      "#{File.dirname(__FILE__)}/../custom_active_table_set.yml"
    end
  end
end
```

If your situation is more complex, you may wish to do something more like the following:

```ruby
module ActiveTableSet
  class DefaultConfigLoader
    def configuration(filename: nil)
      # perform custom logic
      # return hash with structure similar to structure seen in activate_table_set.yml - for instance..
      { table_sets: [common: { partitions: [leader: {...}, followers: [{...},{...}]],
                               readable: [:table_name1, :table_name2],
                               writable: [:table_name3, :table_name4, :table_name5] },
                     realtime: { partitions: [leader: {...}, followers: [{...},{...}]],
                                                              readable: [:table_name1, :table_name2, :table_name7, :table_name8],
                                                              writable: [:table_name10] }
      }
      # each leader and follower has the following format:
      #            host: dns_name or ip_address
      #            database: database_name
      #            username: database_username
      #            password: database_password
      #            timeout: the default timeout for this connection (can be overriden when asking for connection)
    end
  end
end
```


## Concepts

The gem maintains two classes that you will want to interface with directly: ConnectionProxy and TableSetConfig.

The ConnectionProxy is meant to replace the standard Rails AREL ConnectionPool and some of its associated classes. The ConnectionProxy
is instantiated at application start-up - it needs to be in place and ready to go before the app starts loading anything from the
database. It overrides the default AREL request for a connection and replaces it with a more intelligent connection method. For
default connections, things should look the same as they always have. However, for more interesting and performance-intensive cases,
new options become available such as optimizing access permissions and sharding.

The ConnectionProxy maintains a set of TableSets. These are defined in the StaticConfiguration file, and are named, such as :common,
:ringswitch, :network_shard, and so forth. When code requests a connection from ConnectionProxy, it passes the request parameters to one
of its TableSets and gets back a PoolKey. The ConnectionProxy uses that PoolKey to get a ConnectionPool from its PoolManager. It then
passes back a connection from that ConnectionPool.

A TableSet defines a set of one or more partitions. Partitions are explained in the next paragraph. For simple cases, such as our
:common table set definition, there is only one partition. For sharding situations, however, there may be many partitions for a
given table set. TableSets also define a set of writable tables and readable tables. Attempts to perform queries on a TableSet connection
that do not conform to the writable/readable lists will result in an error. For instance, if a TableSet is configured for read-access of
data warehouse tables, a connection from it will inspect and reject queries attempting to write to warehouse tables.

A Partition defines a set of servers, which must contain exactly one leader, as well as zero or more followers. When the partition is asked
for a connection_key, it does so based on the requested access mode. The leader is the correct server for read/write access. It is also the
correct server for typical read access. However, for the :balanced access mode, the partition will choose from among its list of followers
in a load-balanced way using thread-id. This is not round-robin, it's more of a way to parallelize access while maintaining the ability to
leverage caching on both sides of the connection.

The partition defines each server by PoolKey, which is a combination of: host, username, password, and timeout. This is a simple value class.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment. 

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Running Tests

Tests in this gem are written in Rspec and can be executed through the main rake task for the repo
```bash
bundle exec rake
```

If there is a subset of tests you would like to run, you can add the `focus: true` tag to the test or context to only run the subset of tests.

#### Debugging Process Settings
This gem relies on a third party gem called `ProcessSettings` in order to allow for dynamic configuration overrides to be ingested into the currently running process.
The ingestion of changes to this settings file happens in a thread that is started up during the initialization of the `ConnectionHandler` and has it's own logger.
To allow for tests to not have unnecessary noise, by default this logger is writing to `/dev/null`, but if you are trying to debug an issue with the dynamic
processing of these overrides, start the test run with the `DEBUG_PROCESS_SETTINGS` environment variable set to have the `ProcessSetting` thread log to `STDOUT`.
```bash
DEBUG_PROCESS_SETTINGS=true bundle exec rake
```


## Contributing

1. Fork it ( https://github.com/invoca/active_table_set/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
4. Make sure the tests pass: `rspec spec`
5. Create a new Pull Request
