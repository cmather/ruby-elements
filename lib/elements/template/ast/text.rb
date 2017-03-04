require "elements/template/ast/value"

module Elements
  module Template
    module AST
      class Text < Value
        def generate(codegen = Elements::Template::CodeGen.new)
          codegen.fragment(self) do |f|
            f.indent("vtext(").quoted_string(@value).write(")")
          end
        end
      end
    end
  end
end
