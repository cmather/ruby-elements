require "elements/view/ast/node"
require "elements/view/ast/node_collection"
require "elements/view/location"
require "elements/view/assertions"

module Elements
  module View
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
end
