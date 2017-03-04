require "elements/vdom"

module Elements
  module Template
    class Base
      include Elements::VDOM::Helpers

      def initialize(attributes = {}, children = [])
        @attributes = attributes
        @children = children
      end

      def render
      end

      def append_to(element)
      end

      def to_html
      end

      def to_dom
      end
    end
  end
end
