module Elements
  module Template
    class Base
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
