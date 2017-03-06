require "ostruct"

# XXX add event listener methods to Node class.
# XXX add event listener methods to api classes

module Elements
  module VDOM
    module API
      module ServerDOM
        class Node
          include Enumerable

          class NodeNotFoundError < StandardError; end
          class NotSupportedError < StandardError; end

          module NodeTypes
            ELEMENT_NODE = 1
            TEXT_NODE = 3
            DOCUMENT_NODE = 9
          end

          attr_reader :owner_document
          attr_reader :child_nodes
          attr_reader :node_name
          attr_accessor :previous_sibling
          attr_accessor :next_sibling
          attr_accessor :parent_node

          def initialize(document = nil)
            @owner_document = document
            @child_nodes = []
            @next_sibling = nil
            @parent_node = nil
            @previous_sibling = nil
            @text_content = nil
            @node_name = nil
            @props = {}
          end

          # Get a property.
          def [](name)
            @props[name]
          end

          # Set a property.
          def []=(name, value)
            @props[name] = value
          end

          def remove_property(name)
            @props.remove(name)
          end

          def respond_to?(method)
            true
          end

          def inspect
            "<Node##{id}/>"
          end

          def text_content
            reduce("") do |text, node|
              text << node.text_content if node.is_a?(Text)
              text
            end
          end

          def text_content=(text)
            @child_nodes = [Text.new(owner_document, text)]
          end

          def first_child
            @child_nodes.first
          end

          def last_child
            @child_nodes.last
          end

          def node_type
            NodeTypes::DOCUMENT_NODE
          end

          def append_child(node)
            last_child.next_sibling = node if last_child
            node.previous_sibling = last_child
            node.parent_node = self
            child_nodes << node
            self
          end

          def remove_child(node)
            idx = child_nodes.index(node)
            raise NodeNotFoundError unless idx
            before = idx > 0 ? child_nodes[idx - 1] : nil
            after = idx < child_nodes.size - 1 ? child_nodes[idx + 1] : nil
            before.next_sibling = after if before
            after.previous_sibling = before if after
            child_nodes.delete_at(idx)
            node.parent_node = nil
            node.next_sibling = nil
            node.previous_sibling = nil
            self
          end

          def replace_child(new_node, old_node)
            idx = child_nodes.index(old_node)
            raise NodeNotFoundError unless idx
            new_node.previous_sibling = old_node.previous_sibling
            new_node.next_sibling = old_node.next_sibling
            new_node.parent_node = self
            child_nodes[idx] = new_node
            old_node.parent_old_node = nil
            old_node.next_sibling = nil
            old_node.previous_sibling = nil
            self
          end

          def insert_before(new_node, reference_node = nil)
            # if we already have this node in our child node list delete it and
            # then reposition it below. note: if new_node is not in child_nodes
            # the delete method simply returns nil.
            child_nodes.delete(new_node)

            # first if the new
            if reference_node
              idx = child_nodes.index(reference_node)
              raise NodeNotFoundError unless idx

              next_sibling = child_nodes[idx]
              prev_sibling = child_nodes[idx - 1]

              # insert the new node in the right position
              child_nodes.insert(idx, new_node)

              # wire up to the next sibling
              new_node.next_sibling = next_sibling
              next_sibling.previous_sibling = new_node unless next_sibling.nil?

              # wire up to the prev sibling
              new_node.previous_sibling = prev_sibling
              prev_sibling.next_sibling = new_node unless prev_sibling.nil?

            else
              prev_sibling = child_nodes.last
              child_nodes << new_node
              new_node.previous_sibling = prev_sibling
              prev_sibling.next_sibling = new_node unless prev_sibling.nil?
            end

            new_node.parent_node = self
            self
          end

          # Performs a preorder traversal of the DOM tree.
          def each(&block)
            yield self
            child_nodes.each { |n| n.each(&block) }
          end
        end

        class Document < Node
          def create_element(tag)
            Element.new(self, tag)
          end

          def create_element_ns(namespace_uri, tag)
            Element.new(self, tag).tap do |element|
              element.namespace_uri = namespace_uri
            end
          end

          def create_text_node(text)
            Text.new(self, text)
          end
        end

        class Element < Node
          attr_accessor :attributes
          attr_reader :tag_name

          def initialize(document, tag)
            super(document)
            @tag_name = tag.to_s.upcase
            @node_name = @tag_name
            @attributes = {}
          end

          def node_type
            NodeTypes::ELEMENT_NODE
          end

          def set_attribute(name, value)
            @attributes[name.to_s] = value
          end

          def get_attribute(name)
            @attributes[name.to_s]
          end

          def remove_attribute(name)
            @attribtues.delete(name)
          end

          def id
            get_attribute("id")
          end

          def id=(value)
            set_attribute("id", value)
            self
          end

          def namespace_uri
            get_attribute("namespace_uri")
          end

          def namespace_uri=(value)
            set_attribute("namespace_uri", value)
          end

          def outer_html(pretty: false)
            buffer = to_outer_html_buffer()
            return pretty ? pretty_print(buffer) : buffer.join
          end

          def inner_html(pretty: false)
            buffer = to_inner_html_buffer()
            return pretty ? pretty_print(buffer) : buffer.join
          end

          def inspect
            tag = "<#{tag_name.downcase}"

            if @attributes.size > 0
              attrs = @attributes.map { |k, v| "#{k.to_s}=\"#{v.to_s}\"" }.join(" ")
              tag << " #{attrs} />"
            else
              tag << " />"
            end

            tag
          end

          def pretty_print(value, level = 0)
            if value.is_a?(Array)
              return value.reduce("") { |out, v| out << pretty_print(v, level + 1) }
            elsif value.is_a?(String)
              indent = "\s\s" * (level - 1)
              return "#{indent}#{value}\n"
            end
          end

          def to_outer_html_buffer
            [].tap do |buffer|
              if @attributes.size > 0
                attrs = @attributes.map { |k, v| "#{k.to_s}=\"#{v.to_s}\"" }.join(" ")
                buffer << "<#{tag_name.downcase} #{attrs}>"
              else
                buffer << "<#{tag_name.downcase}>"
              end

              child_nodes.each do |child_node|
                if child_node.is_a?(Text)
                  buffer << [child_node.text_content]
                else
                  buffer << child_node.to_outer_html_buffer
                end
              end

              buffer << "</#{tag_name.downcase}>"
            end
          end

          def to_inner_html_buffer
            [].tap do |buffer|
              child_nodes.each do |child_node|
                if child_node.is_a?(Text)
                  buffer << [child_node.text_content]
                else
                  # for the children we want their entire outer html, not just
                  # what's inside so call the to_outer_html_buffer method instead
                  # of to_inner_html_buffer.
                  buffer << child_node.to_outer_html_buffer
                end
              end
            end
          end
        end

        class Text < Node
          def initialize(document, text)
            super(document)
            @text_content = text
            @node_name = "text"
          end

          def text_content
            @text_content
          end

          def text_content=(value)
            @text_content = value
          end

          def append_child(child)
            raise NotSupportedError
          end

          def node_type
            NodeTypes::TEXT_NODE
          end

          def inspect
            text_content
          end

          def to_s
            text_content
          end
        end
      end
    end
  end
end
