require "elements/template/ast/value"

module Elements
  module Template
    module AST
      class Comment < Value
        def generate(codegen = Elements::Template::CodeGen.new)
          (codegen.data[:comments] ||= []) << @value
          codegen.fragment(self) do |f|
            @value.lines.map { |line| f.indent("# ").write(line) }
          end
        end
      end
    end
  end
end
