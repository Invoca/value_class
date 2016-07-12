module ActiveTableSet
  module Extensions
    module ConnectionAdaptersColumnOverride
      # Returns the Ruby class that corresponds to the abstract data type.
      def klass
        case type
          when :integer                     then Fixnum
          when :float                       then Float
          when :decimal                     then BigDecimal
          when :datetime, :timestamp, :time then Time
          when :date                        then Date
          when :text, :string, :binary      then String
          when :boolean                     then Object
          when :varbinary                   then String # Invoca patch
        end
      end

      def type_cast_code(var_name)
        klass = self.class.name

        case type
          when :string, :text        then var_name
          when :integer              then "#{klass}.value_to_integer(#{var_name})"
          when :float                then "#{var_name}.to_f"
          when :decimal              then "#{klass}.value_to_decimal(#{var_name})"
          when :datetime, :timestamp then "#{klass}.string_to_time(#{var_name})"
          when :time                 then "#{klass}.string_to_dummy_time(#{var_name})"
          when :date                 then "#{klass}.string_to_date(#{var_name})"
          when :binary               then "#{klass}.binary_to_string(#{var_name})"
          when :boolean              then "#{klass}.value_to_boolean(#{var_name})"
          when :varbinary            then "#{klass}.binary_to_string(#{var_name})" # Invoca patch
          else var_name
        end
      end

      class << self
        # Used to convert values to integer.
        # handle the case when an integer column is used to store boolean values
        def value_to_integer(value)
          case value
            when TrueClass, FalseClass
              value ? 1 : 0
            when ActiveSupport::OrderedHash # Invoca patch
              value.size
            else
              value.to_i rescue nil
          end
        end
      end

      private

        def simplified_type(field_type)
          case field_type
            when /int/i
              :integer
            when /float|double/i
              :float
            when /decimal|numeric|number/i
              extract_scale(field_type) == 0 ? :integer : :decimal
            when /datetime/i
              :datetime
            when /timestamp/i
              :timestamp
            when /time/i
              :time
            when /date/i
              :date
            when /clob/i, /text/i
              :text
            when /varbinary/i # Invoca patch
              :varbinary
            when /blob/i, /binary/i
              :binary
            when /char/i, /string/i
              :string
            when /boolean/i
              :boolean
          end
        end
    end
  end
end