require "elements/ast/node"
require "elements/ast/node_collection"
require "elements/location"
require "elements/assertions"

module Elements
  module AST
    class AttributeCollection < NodeCollection
      def to_s
        children.map(&:to_s).join(" ")
      end

      def preorder(&block)
        return to_enum(:preorder) unless block_given?
        yield self
        @children.each { |attr| attr.preorder(&block) }
      end
    end
  end
end
