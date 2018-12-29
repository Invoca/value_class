# frozen_string_literal: true

module ActiveTableSet
  class QueryParser
    attr_reader :query, :read_tables, :write_tables, :operation

    def initialize(query)
      @query        = query.dup.force_encoding("BINARY")
      @read_tables  = []
      @write_tables = []
      parse_query(@query)
    end

    private

    MATCH_OPTIONALLY_QUOTED_TABLE_NAME = "[`]?([0-9,a-z,A-Z$_.]+)[`]?"

    SELECT_QUERY = /\A\s*select\s/i
    SELECT_FROM_MATCH = /FROM #{MATCH_OPTIONALLY_QUOTED_TABLE_NAME}/i

    INSERT_QUERY = /\A\s*insert\s(?:ignore\s)?into/i
    INSERT_TARGET_MATCH = /\A\s*insert\s(?:ignore\s)?into\s#{MATCH_OPTIONALLY_QUOTED_TABLE_NAME}/i

    UPDATE_QUERY = /\A\s*update\s/i
    UPDATE_TARGET_MATCH = /\A\s*update\s#{MATCH_OPTIONALLY_QUOTED_TABLE_NAME}/i

    DELETE_QUERY = /\A\s*delete\s/i
    DELETE_TARGET_MATCH = /\A\s*delete.*from\s#{MATCH_OPTIONALLY_QUOTED_TABLE_NAME}/i

    DROP_QUERY = /\A\s*drop\s*table\s/i
    DROP_TARGET_MATCH = /\A\s*drop\s*table\s*(?:if\s+exists)?\s*\s#{MATCH_OPTIONALLY_QUOTED_TABLE_NAME}/i

    CREATE_QUERY = /\A\s*create\s*table\s/i
    CREATE_TARGET_MATCH = /\A\s*create\s*table\s*(?:if\s+exists)?\s*\s#{MATCH_OPTIONALLY_QUOTED_TABLE_NAME}/i

    TRUNCATE_QUERY = /\A\s*truncate\s*table\s/i
    TRUNCATE_TARGET_MATCH = /\A\s*truncate\s*table\s*\s#{MATCH_OPTIONALLY_QUOTED_TABLE_NAME}/i

    OTHER_SQL_COMMAND_QUERY = /\A\s*(?:begin|commit|end|release|savepoint|rollback|show|set|alter|rename)/i

    JOIN_MATCH = /(?:left\souter)?\sjoin\s[`]?([0-9,a-z,A-Z$_.]+)[`]?/im

    # returns the operation
    def parse_query(query)
      clean_query = strip_comments(query)

      @operation =
        case clean_query
        when SELECT_QUERY
          parse_select_query(clean_query, @read_tables)
          :select
        when INSERT_QUERY
          parse_insert_query(clean_query, @read_tables, @write_tables)
          :insert
        when UPDATE_QUERY
          parse_update_query(clean_query, @read_tables, @write_tables)
          :update
        when DELETE_QUERY
          parse_delete_query(clean_query, @read_tables, @write_tables)
          :delete
        when DROP_QUERY
          parse_drop_query(clean_query, @write_tables)
          :drop
        when CREATE_QUERY
          parse_create_query(clean_query, @write_tables)
          :create
        when TRUNCATE_QUERY
          parse_truncate_query(clean_query, @write_tables)
          :truncate
        when OTHER_SQL_COMMAND_QUERY
          :other
        else
          raise "ActiveTableSet::QueryParser.parse_query - unexpected query: #{query}"
        end
    end

    def strip_comments(source_query)
      source_query
        .scrub("*")
        .split("\n")
        .map { |row| row unless row.strip.starts_with?("#") }
        .compact
        .join("\n")
    end

    def parse_select_query(clean_query, read_tables)
      if (table = clean_query[SELECT_FROM_MATCH, 1])
        read_tables << table
      end
      read_tables.concat(parse_joins(clean_query))
    end

    def parse_insert_query(clean_query, read_tables, write_tables)
      if (table = clean_query[INSERT_TARGET_MATCH, 1])
        write_tables << table
      end
      if (table = clean_query[SELECT_FROM_MATCH, 1])
        read_tables << table
      end
      read_tables.concat(parse_joins(clean_query))
    end

    def parse_update_query(clean_query, read_tables, write_tables)
      if (table = clean_query[UPDATE_TARGET_MATCH, 1])
        write_tables << table
      end
      read_tables.concat(parse_joins(clean_query))
    end

    def parse_delete_query(clean_query, read_tables, write_tables)
      if (table = clean_query[DELETE_TARGET_MATCH, 1])
        write_tables << table
      end
      read_tables.concat(parse_joins(clean_query))
    end

    def parse_drop_query(clean_query, write_tables)
      if (table = clean_query[DROP_TARGET_MATCH, 1])
        write_tables << table
      end
    end

    def parse_create_query(clean_query, write_tables)
      if (table = clean_query[CREATE_TARGET_MATCH, 1])
        write_tables << table
      end
    end

    def parse_truncate_query(clean_query, write_tables)
      if (table = clean_query[TRUNCATE_TARGET_MATCH, 1])
        write_tables << table
      end
    end

    # return additional @read_tables
    def parse_joins(clean_query)
      clean_query.scan(JOIN_MATCH).flatten
    end
  end
end
