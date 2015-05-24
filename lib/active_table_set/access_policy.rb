# Policies use the mysql replication wildcard format.
# For example:
# %.cf_%,%.fraud_reports,%.simple_sessions,%.payout_calls_during_check_period%,%.calls_fraud_reports%,%.pnapi_show_responses

module ActiveTableSet
  class AccessPolicy
    include ActiveTableSet::Configurable

    config_description "describes the read write rules for tables using using the mysql wildcard format"

    config_attribute :allow_read,
                     description: "Which tables can be read, defaults to '%'",
                     default: '%'

    config_attribute :allow_write,
                     description: "Which tables can be written, defaults to '%'",
                     default: '%'

    config_attribute :disallow_read,
                     description: "Which tables can not be read, defaults to ''",
                     default: ''

    config_attribute :disallow_write,
                     description: "Which tables can not be written, defaults to ''",
                     default: ''

    def initialize(config = {})
      super

      @allow_read_pattern = parse_pattern(allow_read)
      @allow_write_pattern = parse_pattern(allow_write)
      @disallow_read_pattern = parse_pattern(disallow_read)
      @disallow_write_pattern = parse_pattern(disallow_write)
    end

    def access_rules
      [:allow_read, :disallow_read, :allow_write, :disallow_write].map do |access|
        if (access_str = send(access)) && !access_str.blank?
          "#{access}: #{access_str}"
        end
      end.compact
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
