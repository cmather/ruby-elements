require "elements/view/ast/node"
require "elements/view/location"
require "elements/view/assertions"

module Elements
  module View
    module AST
      class NodeCollection
        include Enumerable
        include Assertions

        attr_reader :parent
        attr_reader :children

        def initialize(parent = nil)
          @parent = parent
          @children = []
        end

        def size
          @children.size
        end

        def [](index)
          @children[index]
        end

        def empty?
          @children.empty?
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

        def last
          @children.last
        end

        def each(&block)
          return to_enum(:each) unless block_given?
          @children.each(&block)
        end

        def preorder(&block)
          return to_enum(:preorder) unless block_given?
          @children.each { |node| node.preorder(&block) }
        end
      end
    end
  end
end
