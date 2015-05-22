# Policies use the mysql replication wildcard format.
# For example.
# %.cf_%,%.fraud_reports,%.simple_sessions,%.payout_calls_during_check_period%,%.calls_fraud_reports%,%.pnapi_show_responses

module ActiveTableSet
  class AccessPolicy
    attr_reader :allow_read, :allow_write, :disallow_read, :disallow_write

    def initialize(allow_read: '%', allow_write: '%', disallow_read: '', disallow_write: '')
      @allow_read = allow_read
      @allow_write = allow_write
      @disallow_read = disallow_read
      @disallow_write = disallow_write

      @allow_read_pattern = parse_pattern(allow_read)
      @allow_write_pattern = parse_pattern(allow_write)
      @disallow_read_pattern = parse_pattern(disallow_read)
      @disallow_write_pattern = parse_pattern(disallow_write)
    end

    def errors(write_tables:, read_tables:)
      [
          allowed_access_errors(@allow_read_pattern, read_tables, 'read'),
          allowed_access_errors(@allow_write_pattern, write_tables, 'write'),
          disallowed_access_errors(@disallow_read_pattern, read_tables, 'read'),
          disallowed_access_errors(@disallow_write_pattern, write_tables, 'write'),
      ].flatten.compact
    end


    private
    def allowed_access_errors(pattern, tables, mode)
      tables.map do |table|
        unless pattern.any? { |pattern| table =~ pattern }
           "Cannot #{mode} #{table}"
        end
      end
    end

    def disallowed_access_errors(pattern, tables, mode)
      tables.map do |table|
        if pattern.any? { |pattern| table =~ pattern }
          "Cannot #{mode} #{table}"
        end
      end
    end

    def parse_pattern(pattern)
      pattern.split(",").reject(&:blank?).map do |sub_pattern|
        Regexp.compile("\\A#{sub_pattern.gsub("%",".*")}\\z")
      end
    end
  end
end

