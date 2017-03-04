require "elements/template/ast/value"

module Elements
  module Template
    module AST
      class AttributeValue < Value
        def to_s
          "\"#{value}\""
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
