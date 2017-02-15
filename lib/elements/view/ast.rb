# XXX design: make "body" "children" for consistency. it's weird to have to
# remember both isn't it? or maybe not.
require "elements/view/location"
require "elements/view/assertions"

module Elements
  module View
    module AST
      class Node
        include Assertions

        attr_reader :location
        attr_accessor :prev_sibling
        attr_accessor :next_sibling
        attr_accessor :parent

        def initialize(location = Location.new)
          @location = location
          @prev_sibling = nil
          @next_sibling = nil
          @parent = nil
        end

        def <<(node)
          raise NotImplementedError
        end
      end

      class NodeCollection
        include Enumerable
        include Assertions

        attr_reader :parent
        attr_reader :children

        def initialize(parent)
          @parent = parent
          @children = []
        end

        def size
          @children.size
        end

        def [](index)
          @children[index]
        end

        def <<(node)
          assert_type Node, node

          # set the parent pointer of the node to this collection's parent.
          node.parent = @parent

          # if we have a previous item in this collection then set the prev/next
          # sibling pointers.
          if @children.last
            @children.last.next_sibling = node
            node.prev_sibling = @children.last
          end

          # finally, add the node to our array of children and return the node.
          @children << node
        end

        def each(&block)
          return to_enum(:each) unless block_given?
          @children.each(&block)
        end
      end

      class Document < Node
        attr_reader :body

        def initialize(location = Location.new)
          super(location)
          @body = NodeCollection.new(self)
        end

        def <<(node)
          @location.finish = node.location.finish.dup
          @body << node
        end
      end

      class Template < Node
        attr_reader :body, :attributes

        def initialize(location = Location.new)
          super(location)
          @attributes = NodeCollection.new(self)
          @body = NodeCollection.new(self)
        end

        def <<(node)
          @body << node
        end
      end

      class Attribute < Node
        attr_reader :name, :value

        def initialize(name, value = true, location = Location.new)
          super(location)
          @name = name
          @value = value
        end
      end

      class Tag < Node
        attr_reader :children
        attr_reader :attributes
        attr_reader :name

        def initialize(name, location = Location.new)
          super(location)
          @name = name
          @children = NodeCollection.new(self)
          @attributes = NodeCollection.new(self)
        end

        def <<(node)
          @children << node
        end
      end

      class Element < Tag
        attr_reader :namespace

        def initialize(name, namespace = nil, location = Location.new)
          super(name, location)
          @namespace = namespace
        end
      end

      class View < Tag; end

      class Value < Node
        attr_reader :value

        def initialize(value, location = Location.new)
          super(location)
          @value = value
        end
      end

      class Any < Value; end
      class Text < Value; end
      class Comment < Value; end
    end
  end
end
