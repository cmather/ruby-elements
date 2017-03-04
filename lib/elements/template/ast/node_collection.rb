require "elements/assertions"
require "elements/template/ast/node"

module Elements
  module Template
    module AST
      class NodeCollection
        include Enumerable
        include Assertions

        attr_reader :parent
        attr_reader :children

        def initialize(parent, options = {})
          @parent = parent
          @children = []
          @options = options
          if (options[:children] && options[:children].respond_to?(:each))
            options[:children].each { |node| add(node) }
          end
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

        def add(node)
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

        alias_method :<<, :add

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

        alias_method :traverse, :preorder
      end
    end
  end
end
