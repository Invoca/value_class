require 'active_record'

module ValueClass
  module ThreadLocalAttribute
    extend ActiveSupport::Concern

    module ClassMethods
      def thread_local_class_attr(name)
        class_eval <<-EORUBY, __FILE__, __LINE__ + 1
          def self.#{name}
            _get_thread_local_atttribute(self.class, '#{name}')
          end

          def self.#{name}=(value)
            _set_thread_local_atttribute(self.class, '#{name}', value)
          end
        EORUBY
      end

      def thread_local_instance_attr(name)
        class_eval <<-EORUBY, __FILE__, __LINE__ + 1
          def #{name}
            self.class._get_thread_local_atttribute(self, '#{name}')
          end

          def #{name}=(value)
            self.class._set_thread_local_atttribute(self, '#{name}', value)
          end
        EORUBY
      end

      def _thread_local_key(object, name)
        "ThreadLocalAttribute:#{object.object_id}:#{name}"
      end

      def _get_thread_local_atttribute(object, name)
        Thread.current.thread_variable_get(_thread_local_key(object, name))
      end

      def _set_thread_local_atttribute(object, name, value)
        Thread.current.thread_variable_set(_thread_local_key(object, name), value)
      end
    end

  end
end
