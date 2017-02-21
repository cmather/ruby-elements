require "elements/view/ast/node"
require "elements/view/ast/node_collection"
require "elements/view/ast/attribute_collection"
require "elements/view/location"
require "elements/view/assertions"

module Elements
  module View
    module AST
      class Tag < Node
        include Enumerable

        attr_reader :children
        attr_reader :attributes
        attr_reader :name

        def initialize(name, location = Location.new)
          super(location)
          @name = name
          @children = NodeCollection.new(self)
          @attributes = AttributeCollection.new(self)
        end

        def <<(node)
          @children << node
        end

        def to_s
          attr_values = if attributes.empty? then "" else " #{attributes}"; end
          has_children_indicator = if children.empty? then "" else "..."; end
          "<#{name}#{attr_values}>#{has_children_indicator}</#{name}>"
        end

        def each(&block)
          return to_enum(:each) unless block_given?
          @children.each(&block)
        end

        def preorder(&block)
          return to_enum(:preorder) unless block_given?
          yield self
          @attributes.preorder(&block)
          @children.preorder(&block)
        end
      end
    end
  end
end
