module ActiveTableSet
  module Configuration
    class AccessPolicy
      include ValueClass::Constructable
      value_attr :allow_read,     default: '%'
      value_attr :allow_write,    default: '%'
      value_attr :disallow_read,  default: ''
      value_attr :disallow_write, default: ''

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
          disallowed_access_errors(@disallow_write_pattern, write_tables, 'write')
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
          Regexp.compile("\\A#{sub_pattern.gsub('%', '.*')}\\z")
        end
      end
    end
  end
end
