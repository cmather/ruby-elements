require "elements/template/ast/tag"
require "elements/core/utils"

module Elements
  module Template
    module AST
      class Template < Tag
        include Core::Utils

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

                # XXX instead of this should it be call(view) which takes a
                # view? could also provide a class method on Template that
                # instantiates a new template like new(opts).call(view). One of
                # the benefits of this approach is that we can assume a variable
                # will be in scope in this method. the "view" which can be
                # passed to a child constructor without actually evaluating it.
                # What about callable things? Should those things be called with
                # a view. oh wait, this is indicating that these methods would
                # be executed as soon as this method is called, vs. in the
                # rendering phase. that would indeed change things
                # substantially. because we would know at the top level what the
                # vnodes will be. no this won't work. it's possible you'd have
                # procs nested very deeply, right? no they'll all be defined in
                # top level scope. look at an example to see. draw out the tag
                # tree.
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
