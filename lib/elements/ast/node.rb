require "elements/assertions"
require "elements/location"

module Elements
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

      # Preorder traversal of the abstract syntax tree.
      def preorder(&block)
        return to_enum(:preorder) unless block_given?
        yield self if block_given?
      end
    end
  end
end
