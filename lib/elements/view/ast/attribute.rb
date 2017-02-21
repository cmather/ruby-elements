require "elements/view/ast/node"
require "elements/view/ast/attribute_name"
require "elements/view/ast/attribute_value"
require "elements/view/location"
require "elements/view/assertions"

module Elements
  module View
    module AST
      class Attribute < Node
        attr_reader :name, :value

        def initialize(name_node, value_node = nil, boolean = false, location = Location.new)
          assert_type AttributeName, name_node
          assert_type_or_nil AttributeValue, value_node
          super(location)
          @name = name_node
          @value = value_node
          @boolean = boolean
        end

        def boolean?
          @boolean == true
        end

        def to_s
          "#{name}=\"#{value}\""
        end

        def preorder(&block)
          return to_enum(:preorder) unless block_given?
          yield self
          @name.preorder(&block)
          @value.preorder(&block)
        end
      end
    end
  end
end
