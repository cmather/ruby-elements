require "elements/assertions"
require "elements/template/location"

module Elements
  module Template
    module AST
      class Document < Node
        include Enumerable

        attr_reader :children

        def initialize(options = {})
          super(options)
          @children = NodeCollection.new(self)
        end

        def <<(node)
          @location.finish = node.location.finish.dup
          @children << node
        end

        def each(&block)
          return to_enum(:each) unless block_given?
          @children.each(&block)
        end

        def preorder(&block)
          return to_enum(:preorder) unless block_given?
          yield self
          @children.preorder(&block)
        end

        def to_s
          @children.map(&:to_s).join
        end

        def generate(codegen = Elements::Template::CodeGen.new)
          codegen.fragment(self) do |f|
            f.indent("require ").quoted_string("elements/template")
            f.newline

            @children.each_with_index do |child_ast, idx|
              f.write child_ast.generate(codegen)
            end
          end
        end
      end
    end
  end
end
