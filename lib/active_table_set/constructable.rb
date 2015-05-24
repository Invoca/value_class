module ActiveTableSet
  module Constructable
    extend ActiveSupport::Concern

    class Attribute
      attr_reader :name, :options
      def initialize( name, options )
        @name = name.freeze
        @options = options.freeze
      end

      def description(prefix="")
        "#{prefix}#{name}"
      end

      def default
        value = options[:default]
        begin
          value.dup
        rescue TypeError
          value
        end
      end
    end

    # Default constructor
    def initialize(config = {})
      self.class.config_attributes.each do |attribute|
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

        instance_variable_set("@#{attribute.name}", second_value || attribute.default)

        if !second_value && attribute.options[:required]
          raise ArgumentError,  "must provide a value for #{attribute.name}"
        end
      end
    end


    def clone_config(&block)
      config = self.class.config_class.new
      self.class.config_attributes.each do |attr|
        current_value = send(attr.name)
        dup_value =
          begin
            current_value.dup
          rescue TypeError
            current_value
          end
        config.send("#{attr.name}=", dup_value)
      end
      yield config
      self.class.new(config)
    end


    module ClassMethods
      # Provide a description for the class. This is only used for documentation.
      def config_description(value=nil)
        if value
          @config_description = value
        end
        @config_description
      end

      # Defines a config attribute.
      def config_attribute(attribute_name, options= {})
        attribute = Attribute.new(attribute_name, options)
        config_attributes << attribute

        # All attributes have a reader
        attr_reader(attribute.name)
        config_class.send(:attr_reader, attribute.name)


        # Define the writer on the config class
        config_class.send(:attr_writer, attribute.name)

        # Define a reader on the config class that does assignement from a block
        if class_name = options[:class_name]
          config_class.send(:attr_reader, attribute.name)
          config_class.class_eval <<-EORUBY, __FILE__, __LINE__ + 1
            def #{attribute.name}(&blk)
              if blk
                @#{attribute.name} = #{class_name}.config { |config| yield config }
              end
              @#{attribute.name}
            end
          EORUBY
        end
      end

      def config_list_attribute(attribute_name, options= {})
        config_attribute(attribute_name, options.merge(default:[], class_name: nil, list_of_class: options[:class_name]))

        if (insert_method = options[:insert_method])
          if (class_name = options[:class_name])
            config_class.class_eval <<-EORUBY, __FILE__, __LINE__ + 1
              def #{insert_method}(value=nil, &blk)
                if blk
                  @#{attribute_name} << #{class_name}.config { |config| yield config }
                else
                  @#{attribute_name} << value.map { |v| #{class_name}.new(v) }
                end
                @#{attribute_name}
              end
            EORUBY
          else
            config_class.class_eval <<-EORUBY, __FILE__, __LINE__ + 1
              def #{insert_method}(value)
                @#{attribute_name} << value
                @#{attribute_name}
              end
            EORUBY
          end
        end
      end


      # Constructs an instance using the configuration created in the passed
      # in block.
      def config(&block)
        config = config_class.new
        config_attributes.each do |attr|
          if attr.default
            config.send("#{attr.name}=", attr.default)
          end
        end
        yield config
        new(config)
      end

      def config_help(prefix = "")
        [
            "#{name}: #{config_description}",
            "  attributes:",
            config_attributes.map { |ca| ca.description(prefix + "    ") }
        ].flatten.join("\n") + "\n"
      end

      def config_class
        @config_class ||= Class.new
      end

      def config_help(prefix = "")
        [
            "#{name}: #{config_description}",
            "  attributes:",
            config_attributes.map { |ca| ca.description(prefix + "    ") }
        ].flatten.join("\n") + "\n"
      end

      def config_attributes
        @config_attributes ||= []
      end
    end
  end
end
