module ActiveTableSet
  module Extensions
    module AbstractMysqlAdapterColumnOverride
      def extract_limit(sql_type)
        case sql_type
          when /blob|text/i
            case sql_type
              when /tiny/i
                255
              when /medium/i
                16777215
              when /long/i
                4294967295
              else
                super # we could return 65535 here, but we leave it undecorated by default
            end
          when /^bigint/i;    8
          when /^int/i;       4
          when /^mediumint/i; 3
          when /^smallint/i;  2
          when /^tinyint/i;   1
          when /^enum\((.+)\)/i
            $1.split(',').map{|enum| enum.strip.length - 2}.max
          else
            super
        end
      end
    end

    module AbstractMysqlAdapterOverride
      NATIVE_DATABASE_TYPES = {
          :primary_key              => "int auto_increment PRIMARY KEY",
          :primary_key_no_increment => "int(11) PRIMARY KEY", # Invoca patch
          :string                   => { :name => "varchar", :limit => 255 },
          :text                     => { :name => "text" },
          :integer                  => { :name => "int", :limit => 4 },
          :float                    => { :name => "float" },
          :decimal                  => { :name => "decimal" },
          :datetime                 => { :name => "datetime" },
          :timestamp                => { :name => "datetime" },
          :time                     => { :name => "time" },
          :date                     => { :name => "date" },
          :binary                   => { :name => "blob" },
          :boolean                  => { :name => "tinyint", :limit => 1 },
          :varbinary                => { :name => "varbinary", :limit=> 255 } # Invoca patch
      }

      def quote(value, column = nil)
        if value.kind_of?(String) && column && [:binary, :varbinary].include?(column.type) && column.class.respond_to?(:string_to_binary)
          s = column.class.string_to_binary(value).unpack("H*")[0]
          "x'#{s}'"
        elsif value.kind_of?(BigDecimal)
          value.to_s("F")
        else
          super
        end
      end

      def execute(sql, name = nil)
        if name == :skip_logging
          # TODO: reference the module for `non_nil_connection`?
          non_nil_connection.query(sql)
        else
          log(sql, name) { non_nil_connection.query(sql) }
        end
      rescue ActiveRecord::StatementInvalid => exception
        if exception.message.split(":").first =~ /Packets out of order/
          raise ActiveRecord::StatementInvalid, "'Packets out of order' error was received from the database. Please update your mysql bindings (gem install mysql) and read http://dev.mysql.com/doc/mysql/en/password-hashing.html for more information. If you're on Windows, use the Instant Rails installer to get the updated mysql bindings."
        else
          raise
        end
      end

      def update_sql(sql, name = nil) #:nodoc:
        @connection = non_nil_connection
        super
      end

      def trigger_dump
        triggers = ApplicationModel.connection.select_all("show triggers").map do |row|
          ApplicationModel.connection.select_one("show create trigger #{row['Trigger']}")['SQL Original Statement'].sub(/ DEFINER.*TRIGGER/, ' TRIGGER') +
              "\n//"
        end

        "DELIMITER //\n#{triggers.join("\n")}\nDELIMITER ;\n"
      end
    end
  end
end
