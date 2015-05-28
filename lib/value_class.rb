# TODO - Needs to implement comparison operators using attr_comparible. (Possibly declare in constructor?)
# TODO - Should support eql and hash notation.
# TODO - Add eql and hash notation to attr_comparible

require 'active_record'
require 'attr_comparable'
require 'active_support/core_ext'

require 'value_class/attribute'

module ValueClass
  extend ActiveSupport::Concern

  # Default constructor
  def initialize(config = {})
    self.class.declare_comparison_operators
    self.class.value_attributes.each do |attribute|
      instance_variable_set("@#{attribute.name}", attribute.get_value(config))
    end
  end

  def eql?(other)
    self == other
  end

  def hash
    self.class.value_attributes.map do |attribute|
      instance_variable_get("@#{attribute.name}")
    end.hash
  end

  module ClassMethods
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
      value_attributes << attribute

      attr_reader(attribute.name)
    end

    def value_attrs(*args)
      options = args.extract_options!
      args.each { |arg| value_attr(arg, options) }
    end

    def config_help(prefix = "")
      [
          "#{name}: #{value_description}",
          "  attributes:",
          value_attributes.map { |ca| ca.description(prefix + "    ") }
      ].flatten.join("\n") + "\n"
    end

    def value_attributes
      @value_attrs ||= []
    end

    def declare_comparison_operators
      unless @comparison_operators_declared
        @comparison_operators_declared = true

        include AttrComparable
        attr_compare(value_attributes.map(&:name))
      end
    end
  end
end

# Constructable builds off of the above, so we require it last.
require 'value_class/constructable'