module Elements
  module Core
    module Events
      GLOBAL_EVENT = "all"

      def self.included(base)
        base.class_exec do
          def self.inherited(subclass)
            subclass.instance_variable_set("@listeners", listeners.dup)
          end
        end

        base.extend SharedMethods
        base.include SharedMethods
        base.include InstanceMethods
      end

      module SharedMethods
        def add_event_listener(event, method = nil, &handler)
          listeners[event] << (method || handler)
          self
        end

        def remove_event_listener(event, handler)
          listeners[event].delete(handler)
          self
        end

        def listeners
          @listeners ||= EventMap.new
        end

        alias_method :on, :add_event_listener
        alias_method :off, :remove_event_listener
      end

      module InstanceMethods
        def trigger(event, *args)
          # class listeners
          self.class.listeners[GLOBAL_EVENT].each { |listener| call_listener(listener, event, *args) }
          self.class.listeners[event].each { |listener| call_listener(listener, *args) }

          # instance listeners.
          listeners[GLOBAL_EVENT].each { |listener| call_listener(listener, event, *args) }
          listeners[event].each { |listener| call_listener(listener, *args) }

          self
        end

        def count_listeners(event)
          listeners[event].size + self.class.listeners[event].size
        end

        private
        def call_listener(listener, *args)
          case listener
          when Proc
            instance_exec(*args, &listener)
          when Symbol, String
            send(listener, *args)
          else
            raise TypeError, "unrecognized event listener type: #{listener.inspect}."
          end
        end
      end

      class EventMap
        include Enumerable

        def initialize
          @listeners = {}
        end

        def dup
          EventMap.new.tap do |cloned|
            @listeners.each { |event, handlers| cloned[event] = handlers.dup }
          end
        end

        def [](event)
          @listeners[event] ||= []
        end

        def []=(event, handlers)
          @listeners[event] = handlers
        end

        def each(&block)
          @listeners.each(&block)
        end
      end
    end
  end
end
