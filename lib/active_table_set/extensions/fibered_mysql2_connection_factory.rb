require 'active_table_set/fibered_mysql2_adapter'


module EM::Synchrony
  module ActiveRecord
    _ = Adapter_4_2
    module Adapter_4_2
      def configure_connection
        super                   # undo EM::Synchrony's override here
      end
    end
  end
end


module ActiveTableSet
  module Extensions
    module FiberedMysql2ConnectionFactory
      def fibered_mysql2_connection(raw_config)
        config = raw_config.symbolize_keys

        config[:username] = 'root' if config[:username].nil?
        config[:flags]    = Mysql2::Client::FOUND_ROWS if Mysql2::Client.const_defined?(:FOUND_ROWS)

        client =
            begin
              Mysql2::EM::Client.new(config)
            rescue Mysql2::Error => error
              if error.message.include?("Unknown database")
                raise ActiveRecord::NoDatabaseError.new(error.message, error)
              else
                raise
              end
            end

        options = [config[:host], config[:username], config[:password], config[:database], config[:port], config[:socket], 0]
        FiberedMysql2Adapter.new(client, logger, options, config)
      end
    end
  end
end
