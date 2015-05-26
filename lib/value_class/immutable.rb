module ValueClass
  module Immutable
    extend ActiveSupport::Concern

    # Default constructor
    def initialize(config = {})
      self.class.value_attrs.each do |attribute|
        instance_variable_set("@#{attribute.name}", attribute.get_value(config))
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
