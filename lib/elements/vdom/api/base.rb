module Elements
  module VDOM
    module API
      class Base
        def create_element(tag)
          raise NotImplementedError
        end

        def create_text_node(text)
          raise NotImplementedError
        end

        def parent_node(node)
          raise NotImplementedError
        end

        def next_sibling(node)
          raise NotImplementedError
        end

        def append_child(parent, child)
          raise NotImplementedError
        end

        def remove_child(parent, child)
          raise NotImplementedError
        end

        def insert_before(parent, node, sibling)
          raise NotImplementedError
        end

        def child_nodes(element)
          raise NotImplementedError
        end

        def first_child(node)
          raise NotImplementedError
        end

        def node_name(node)
          raise NotImplementedError
        end

        def node_type(node)
          raise NotImplementedError
        end

        def set_attribute(node, key, value)
          raise NotImplementedError
        end

        def get_attribute(node, key)
          raise NotImplementedError
        end

        def remove_attribute(node, key)
          raise NotImplementedError
        end

        def get_prop(node, key)
          raise NotImplementedError
        end

        def set_prop(node, key, value)
          raise NotImplementedError
        end

        def remove_prop(node, key)
          raise NotImplementedError
        end

        def text_content(node)
          raise NotImplementedError
        end

        def set_text_content(node, text)
          raise NotImplementedError
        end

        def document
          raise NotImplementedError
        end
      end
    end
  end
end
