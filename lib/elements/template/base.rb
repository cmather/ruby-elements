require "elements/vdom"

module Elements
  module Template
    class Base
      include Elements::VDOM::Helpers

      def initialize(view, **attributes, &block)
        @view = view
        @attributes = attributes

        # For inline views a block can be provided which will become the render
        # method.
        if block_given?
          define_singleton_method(:render) do
            @view.instance_eval(&block)
          end
        end
      end

      def render
        []
      end

      # Returns a string of html based on the contents of the template.
      def to_html
      end

      # Returns a new dom fragment.
      def to_dom
      end
    end
  end
end
