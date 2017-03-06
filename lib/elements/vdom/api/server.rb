require "elements/vdom/api/base"
require "elements/vdom/api/server_dom"

module Elements
  module VDOM
    module API
      class Server < Base
        def create_element(tag)
          document.create_element(tag)
        end

        def create_text_node(text)
          document.create_text_node(text)
        end

        def parent_node(node)
          node.parent_node
        end

        def next_sibling(node)
          node.next_sibling
        end

        def append_child(parent, child)
          parent.append_child(child)
        end

        def remove_child(parent, child)
          parent.remove_child(child)
        end

        def insert_before(parent, node, sibling)
          parent.insert_before(node, sibling)
        end

        def child_nodes(node)
          node.child_nodes
        end

        def first_child(node)
          node.first_child
        end

        def node_name(node)
          node.node_name
        end

        def node_type(node)
          node.node_type
        end

        def get_prop(node, key)
          node[key]
        end

        def set_prop(node, key, value)
          node[key] = value
        end

        def remove_prop(node, key)
          node.remove_property(key)
        end

        def set_attribute(node, key, value)
          node.set_attribute(key, value)
        end

        def get_attribute(node, key)
          node.get_attribute(key)
        end

        def remove_attribute(node, key)
          node.remove_attribute(key)
        end

        def text_content(node)
          node.text_content
        end

        def set_text_content(node, text)
          node.text_content = text
        end

        def document
          @document ||= VDOM::API::ServerDOM::Document.new
        end
      end
    end
  end
end
