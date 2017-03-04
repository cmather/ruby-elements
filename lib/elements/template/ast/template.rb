require "elements/template/ast/tag"

module Elements
  module Template
    module AST
      class Template < Tag
        def initialize(options = {})
          # The @name attribute will be "Template".
          super("Template", options)
          @inline = !!options[:inline]
        end

        def inline?
          @inline
        end

        def generate(codegen = Elements::Template::CodeGen.new)
          if inline? then super(codegen) else generate_class(codegen); end
        end

        private
        def generate_class(codegen = Elements::Template::CodeGen.new)
          codegen.fragment(self) do |f|
            if @attributes.has_key?("name")
              # If the template has a name attribute then use that as the
              # module names and class name.
              modules = @attributes["name"].split("::")
              class_name = modules.pop
            elsif @filepath != nil
              # Otherwise use the filepath as the module names and class name.
              modules = @filepath.split(File::SEPARATOR)
              class_name = modules.pop
            else
              raise "Missing template name. Either set the name attribute or the filepath on the ast node."
            end

            f.with_modules(modules) do
              f.with_class(class_name, superclass: "Elements::Template::Base") do
                f.indent "def default_options"
                f.newline
                f.indent do
                  f.indent "{"
                  f.newline
                  f.indent do
                    generate_attributes(codegen, f)
                  end
                  f.newline
                  f.indent "}"
                end
                f.newline
                f.indent "end"

                f.newline
                f.newline

                f.indent "def children"
                f.newline
                f.indent do
                  f.indent "["
                  f.newline
                  f.indent do
                    generate_children(codegen, f)
                  end
                  f.newline
                  f.indent "]"
                end
                f.newline
                f.indent "end"
              end
            end
          end
        end
      end
    end
  end
end
