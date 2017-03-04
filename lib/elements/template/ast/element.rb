require "elements/template/ast/tag"

module Elements
  module Template
    module AST
      class Element < Tag
        attr_reader :namespace

        def initialize(name, options = {})
          super(name, options)
          @namespace = options[:namespace]
        end

        def generate(codegen = Elements::Template::CodeGen.new)
          codegen.fragment(self) do |f|
            f.indent("vnode(").quoted_string(@name).write(", {")
            f.newline
            f.indent do
              generate_attributes(codegen, f)
            end
            f.newline
            f.indent "}, ["
            f.newline
            f.indent do
              generate_children(codegen, f)
            end
            f.newline
            f.indent "])"
          end
        end
      end
    end
  end
end
