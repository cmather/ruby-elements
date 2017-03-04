require "elements/template/ast/node"

module Elements
  module Template
    module AST
      class Tag < Node
        include Enumerable

        attr_reader :children
        attr_reader :attributes
        attr_reader :name

        def initialize(name, options = {})
          super(options)
          @name = name
          @children = NodeCollection.new(self, options)
          @attributes = AttributeCollection.new(self, options)
        end

        def add(node)
          @children << node
        end

        alias_method :<<, :add

        def first
          @children.first
        end

        def last
          @children.last
        end

        def to_s
          attr_values = if attributes.empty? then "" else " #{attributes}"; end
          has_children_indicator = if children.empty? then "" else "..."; end
          "<#{name}#{attr_values}>#{has_children_indicator}</#{name}>"
        end

        def each(&block)
          return to_enum(:each) unless block_given?
          @children.each(&block)
        end

        def preorder(&block)
          return to_enum(:preorder) unless block_given?
          yield self
          @attributes.preorder(&block)
          @children.preorder(&block)
        end

        def generate(codegen = Elements::Template::CodeGen.new)
          codegen.fragment(self) do |f|
            f.indent(@name).write(".new({")

            if @attributes.empty?
              f.write "}, ["
            else
              f.newline
              f.indent do
                generate_attributes(codegen, f)
              end
              f.newline
              f.indent "}, ["
            end

            if @children.empty?
              f.write "])"
            else
              f.newline
              f.indent do
                generate_children(codegen, f)
              end
              f.newline
              f.indent "])"
            end
          end
        end

        private
        def generate_attributes(codegen, fragment)
          @attributes.each_with_index do |child_ast, idx|
            if idx > 0
              fragment.write ","
              fragment.newline
            end

            fragment.write child_ast.generate(codegen)
          end
        end

        def generate_children(codegen, fragment)
          @children.each_with_index do |child_ast, idx|
            if idx > 0
              fragment.write ","
              fragment.newline
            end
            fragment.write child_ast.generate(codegen)
          end
        end
      end
    end
  end
end
