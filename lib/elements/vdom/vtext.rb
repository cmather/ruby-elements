require "elements/vdom/vnode"

module Elements
  module VDOM
    # FIXME this should inherit from base but need to fix up the methods and
    # tests.
    class VText < VNode
      attr_reader :text

      def initialize(text)
        super("text", key: nil)
        @text = text
      end

      def patchable?(element)
        api.node_type(element) == 3
      end

      def patch(old_text_node, insert_queue = [])
        if api.text_content(old_text_node) != text
          api.set_text_content(old_text_node, text)
        end
        old_text_node
      end

      def patch_children(old_node, insert_queue)
        # noop
      end

      def inspect
        "<VText text=\"#{text}\">"
      end

      def to_html_buffer
        [@text]
      end

      protected
      def create_dom_node
        api.create_text_node(text)
      end
    end
  end
end
