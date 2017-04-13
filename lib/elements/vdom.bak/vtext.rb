require "elements/vdom/vnode"

module Elements
  module VDOM
    class VText < VNode
      attr_reader :text

      def initialize(text)
        @text = text.to_s
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

      def to_dom(insert_queue = [])
        api.create_text_node(@text).tap do |text_node|
          insert_queue << OpenStruct.new(vnode: self, node: text_node)
          trigger(Events::CREATE, text_node)
        end
      end

      def to_html_buffer
        [@text]
      end

      private
      def create_dom_node
        api.create_text_node(text)
      end
    end
  end
end
