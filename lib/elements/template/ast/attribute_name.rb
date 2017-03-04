require "elements/template/ast/value"

module Elements
  module Template
    module AST
      class AttributeName < Value
        def to_s
          @value.to_s
        end

        def generate(codegen = Elements::Template::CodeGen.new)
          codegen.fragment(self) do |f|
            f.quoted_string @value
          end
        end
      end
    end
  end
end
