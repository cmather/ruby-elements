require "elements/assertions"
require "elements/template/location"

module Elements
  module Template
    module AST
      class Value < Node
        attr_reader :value

        def initialize(value, options = {})
          super(options)
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

        def generate(codegen = Elements::Template::CodeGen.new)
          codegen.fragment(self) do |f|
            f.indent @value
          end
        end
      end
    end
  end
end
