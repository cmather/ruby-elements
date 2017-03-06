require "elements/vdom/api/base"

module Elements
  module VDOM
    module API
      class Browser < Base
        def create_element(tag)
          document.create_element(tag)
        end

        def create_text_node(text)
          document.create_text_node(text)
        end

        def parent_node(node)
          DOM(node).parent
        end

        def next_sibling(node)
          DOM(node).next
        end

        def append_child(parent, child)
          DOM(parent).add_child(child)
        end

        def remove_child(parent, child)
          DOM(parent).remove_child(child)
        end

        def insert_before(parent, node, sibling)
          DOM(sibling).add_previous_sibling(node)
        end

        def child_nodes(node)
          DOM(node).children
        end

        def first_child(node)
          DOM(node).children.first
        end

        def node_name(node)
          DOM(node).name
        end

        def node_type(node)
          DOM(node).node_type
        end

        def get_prop(node, key)
          Native(`node`)[key]
        end

        def set_prop(node, key, value)
          Native(`node`)[key] = value
        end

        def remove_prop(node, key)
          `delete node[key]`
        end

        def set_attribute(node, key, value)
          DOM(node).set_attribute(key, value)
        end

        def get_attribute(node, key)
          DOM(node).get_attribute(key)
        end

        def remove_attribute(node, key)
          DOM(node).remove_attribute(key)
        end

        def text_content(node)
          DOM(node).text
        end

        def set_text_content(node, text)
          DOM(node).text = text
        end

        def document
          $document
        end
      end
    end
  end
end
