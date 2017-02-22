require "elements/ast/node"
require "elements/ast/node_collection"
require "elements/location"
require "elements/assertions"

module Elements
  module AST
    class Document < Node
      include Enumerable

      attr_reader :children

      def initialize(location = Location.new)
        super(location)
        @children = NodeCollection.new(self)
      end

      def <<(node)
        @location.finish = node.location.finish.dup
        @children << node
      end

      def each(&block)
        return to_enum(:each) unless block_given?
        @children.each(&block)
      end

      def preorder(&block)
        return to_enum(:preorder) unless block_given?
        yield self
        @children.preorder(&block)
      end
    end
  end
end
