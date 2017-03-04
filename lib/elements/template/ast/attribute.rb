require "elements/template/ast/node"

module Elements
  module Template
    module AST
      class Attribute < Node
        attr_reader :name, :value

        def initialize(name, value = nil, options = {})
          assert_type AttributeName, name
          assert_type_or_nil AttributeValue, value
          super(options)
          @name = name
          @value = value
        end

        def boolean?
          @value.nil?
        end

        def to_s
          if boolean? then name.to_s else "#{name}=#{value}"; end
        end

        def preorder(&block)
          return to_enum(:preorder) unless block_given?
          yield self
          @name.preorder(&block)
          @value.preorder(&block)
        end

        def generate(codegen = Elements::Template::CodeGen.new)
          codegen.fragment(self) do |f|
            f.indent(@name.generate(codegen)).write(" => ").write(@value.generate(codegen))
          end
        end
      end
    end
  end
end
