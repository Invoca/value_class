module ValueClass
  module Immutable
    extend ActiveSupport::Concern

    # Default constructor
    def initialize(config = {})
      self.class.value_attrs.each do |attribute|
        ############################################################
        # TODO - this can move to attribute
        raw_value =
            if config.is_a?(Hash)
              config[attribute.name]
            else
              config.send(attribute.name)
            end

        second_value =
            if raw_value.is_a?(Array) && attribute.options[:list_of_class]
              inner_class = attribute.options[:list_of_class]
              raw_value.map { |v| inner_class.constantize.new(v)}
            elsif attribute.options[:class_name] && raw_value
              attribute.options[:class_name].constantize.new(raw_value)
            else
              raw_value
            end
        ############################################################

        instance_variable_set("@#{attribute.name}", second_value || attribute.default)

        if !second_value && attribute.options[:required]
          raise ArgumentError,  "must provide a value for #{attribute.name}"
        end
      end
    end

    module ClassMethods
      def value_attrs
        @value_attrs ||= []
      end

      def value_description(value=nil)
        if value
          @value_description = value
        end
        @value_description
      end

      def value_list_attr(attribute_name, options= {})
        value_attr(attribute_name, options.merge(default:[], class_name: nil, list_of_class: options[:class_name]))
      end

      def value_attr(attribute_name, options= {})
        attribute = Attribute.new(attribute_name, options)
        value_attrs << attribute

        attr_reader(attribute.name)
      end

      def config_help(prefix = "")
        [
            "#{name}: #{value_description}",
            "  attributes:",
            value_attrs.map { |ca| ca.description(prefix + "    ") }
        ].flatten.join("\n") + "\n"
      end
    end
  end
end
