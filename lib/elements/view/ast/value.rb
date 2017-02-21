require "elements/view/ast/node"
require "elements/view/location"
require "elements/view/assertions"

module Elements
  module View
    module AST
      class Value < Node
        attr_reader :value

        def initialize(value, location = Location.new)
          super(location)
          @value = value
        end

        def to_s
          max_size = 50
          value = @value.to_s
          if value.size > max_size then "#{value[0..max_size]}..." else value; end
        end

        def preorder(&block)
          return to_enum(:preorder) unless block_given?
          yield self
        end
      end
    end
  end
end
