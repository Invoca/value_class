module ActiveTableSet
  class QueryParser
    attr_reader :query, :read_tables, :write_tables, :operation

    def initialize(query)
      @query = query
      @read_tables = []
      @write_tables = []
      parse_query
    end

    private

    MATCH_OPTIONALLY_QUOTED_TABLE_NAME = "[`]?([0-9,a-z,A-Z$_.]+)[`]?"

    SELECT_QUERY = /\A\s*select\s/i
    SELECT_FROM_MATCH = /FROM #{MATCH_OPTIONALLY_QUOTED_TABLE_NAME}/i

    INSERT_QUERY = /\A\s*insert\sinto/i
    INSERT_TARGET_MATCH = /\A\s*insert\sinto\s#{MATCH_OPTIONALLY_QUOTED_TABLE_NAME}/i

    UPDATE_QUERY = /\A\s*update\s/i
    UPDATE_TARGET_MATCH = /\A\s*update\s#{MATCH_OPTIONALLY_QUOTED_TABLE_NAME}/i

    DELETE_QUERY = /\A\s*delete\s/i
    DELETE_TARGET_MATCH = /\A\s*delete.*from\s#{MATCH_OPTIONALLY_QUOTED_TABLE_NAME}/i

    OTHER_SQL_COMMAND_QUERY = /\A\s*(?:begin|commit|end|release|savepoint)\s/i

    JOIN_MATCH = /(?:left\souter)?\sjoin\s[`]?([0-9,a-z,A-Z$_.]+)[`]?/im

    def parse_query
      case
      when query =~ SELECT_QUERY
        parse_select_query
      when query =~ INSERT_QUERY
        parse_insert_query
      when query =~ UPDATE_QUERY
        parse_update_query
      when query =~ DELETE_QUERY
        parse_delete_query
      when query = OTHER_SQL_COMMAND_QUERY
        @operation = :other
      else
        raise "unexpected query #{query}"
      end
    end

    def parse_select_query
      @operation = :select
      if query =~ SELECT_FROM_MATCH
        @read_tables << $1
      end
      parse_joins
    end

    def parse_insert_query
      @operation = :insert
      if query =~ INSERT_TARGET_MATCH
        @write_tables << $1
      end
      parse_joins
    end

    def parse_update_query
      @operation = :update
      if query =~ UPDATE_TARGET_MATCH
        @write_tables << $1
      end
      parse_joins
    end

    def parse_delete_query
      @operation = :delete
      if query =~ DELETE_TARGET_MATCH
        @write_tables << $1
      end
      parse_joins
    end

    def parse_joins
      @read_tables += query.scan(JOIN_MATCH).flatten
    end
  end
end
