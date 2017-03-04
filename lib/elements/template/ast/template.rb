require "elements/template/ast/tag"
require "elements/utils"

module Elements
  module Template
    module AST
      class Template < Tag
        include Utils

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
              modules = File.dirname(@filepath).split(File::SEPARATOR).map { |s| camelize(s) }
              class_name = "Template"
            else
              raise "Missing template name. Either set the name attribute or the filepath on the ast node."
            end

            f.with_modules(modules) do
              f.with_class(class_name, superclass: "Elements::Template::Base") do
                f.indent "def default_options"
                f.newline
                f.indent do
                  f.indent "{"

                  if @attributes.empty?
                    f.write "}"
                  else
                    f.newline
                    f.indent do
                      generate_attributes(codegen, f)
                    end
                    f.newline
                    f.indent "}"
                  end
                end

                f.newline
                f.indent "end"

                f.newline
                f.newline

                f.indent "def children"
                f.newline
                f.indent do
                  f.indent "["

                  if @children.empty?
                    f.write "]"
                  else
                    f.newline
                    f.indent do
                      generate_children(codegen, f)
                    end
                    f.newline
                    f.indent "]"
                  end
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
