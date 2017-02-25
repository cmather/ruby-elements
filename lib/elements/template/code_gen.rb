require "sourcemap"
require "elements/assertions"
require "elements/template/location"

module Elements
  module Template
    class CodeGen
      attr_reader :comments
      attr_reader :result
      attr_reader :sourcemap

      def initialize(options = {})
        @options = options
        @options[:indent] ||= "  "
      end

      def generate(node)
        @fragments = []
        @comments = []
        @current_node = nil
        @indent = ""
        generate_from(node)
        @sourcemap = generate_sourcemap(@fragments)
        @result = @fragments.map(&:code)
      end

      private
      def generate_from(node)
        case node
        when AST::Document            then generate_document(node)
        when AST::Any                 then generate_any(node)
        when AST::Template            then generate_template(node)
        when AST::Element             then generate_element(node)
        when AST::View                then generate_view(node)
        when AST::Text                then generate_text(node)
        when AST::Comment             then generate_comment(node)
        when AST::AttributeCollection then generate_attribute_collection(node)
        when AST::Attribute           then generate_attribute(node)
        when AST::AttributeName       then generate_attribute_name(node)
        when AST::AttributeValue      then generate_attribute_value(node)
        else
          raise "Unable to generate code for unrecognized AST node: #{node}"
        end
      end

      def generate_document(node)
        assert_type AST::Document, node
        generate_preamble
        node.children.each { |child| generate(child) }
      end

      def generate_preamble
        push "require ", quoted_string("elements/template")
        empty_line
        empty_line
      end

      def generate_any(node)
        assert_type AST::Any, node
        push node.value, node
      end

      def generate_template(node)
        assert_type AST::Template, node

        with_current_node(node) do
          name = node.attributes["name"]

          if node.inline?
            push "Template.new(["
            indent do
              node.children.each_with_index do |child_node, idx|
                generate(child_node)
                push ",\n" if idx < node.children.size - 1
              end
            end
            push "])"
          else
            push "class #{name} < Elements::Template::Base"
            indent do
              line "def call"
              indent do
                generate_children(node)
                line "["
                indent do
                  node.children.each_with_index do |child_node, idx|
                    generate(child_node)
                    push ",\n" if idx < node.children.size - 1
                  end
                end
                line "]"
              end
              line "end"
            end
          end
        end
      end

      def generate_children(node)
        assert_type AST::Node, node
        assert_respond_to :children, node
        push "["
        indent do
          child_count = node.children.size
          # XXX in this push case we don't want to indent here. so probably want
          # another method other than push that does this?
          push "\n" if child_count > 0
          node.children.each_with_index do |child_node, idx|
            generate_from(child_node)
          end
        end
        push "]"
      end

      def generate_element(node)
        assert_type AST::Element, node

        with_current_node(node) do
          name = node.namespace ? "#{node.namespace}:#{node.name}" : node.name
          push "vnode(", quoted_string(name), ", "
          generate_attribute_collection(node.attributes)
          push ", ["
          indent do
            node.children.each_with_index do |child_node, idx|
              # XXX what is the right way to do a line here? we really want to
              # indent, create a newline and then generate some code
            end
          end
          push "])"
        end
      end

      def generate_tag_children(node)
        assert_type AST::Tag, node
        push "["
        indent do
          node.children.each_with_index do |child_node, idx|
            generate_from(child_node)
            push "," if idx < node.children.size - 1
          end
        end
        push "]"
      end

      def generate_view(node)
        assert_type AST::View, node
      end

      def generate_text(node)
        assert_type AST::Text, node
        push "vtext(", quoted_string(node.value), ")"
      end

      def generate_comment(node)
        assert_type AST::Comment, node
        @comments << node.value
        push "vcomment(", quoted_string(node.value), ")"
      end

      def generate_attribute_collection(node)
        assert_type AST::AttributeCollection, node

        with_current_node(node) do
          push "{"

          node.each_with_index do |attr, idx|
            generate_attribute(attr)
            push ", " if idx < node.size - 1
          end

          push "}"
        end
      end

      def generate_attribute(node)
        assert_type AST::Attribute, node
        with_current_node(node) do
          generate_attribute_name(node.name)
          push " => "
          generate_attribute_value(node.value)
        end
      end

      def generate_attribute_name(node)
        assert_type AST::AttributeName, node
        with_current_node(node) do
          push quoted_string(node.value)
        end
      end

      def generate_attribute_value(node)
        assert_type AST::AttributeValue, node
        with_current_node(node) do
          push quoted_string(node.value)
        end
      end

      def quoted_string(value)
        "\"#{value}\""
      end

      def indent(&block)
        indent = @indent
        @indent += @options[:indent]
        result = yield
        @indent = indent
        result
      end

      def line(*strs)
        push "\n#{@indent}"
        push(*strs)
      end

      def empty_line
        push "\n"
      end

      def push(*strs)
        strs.each do |str|
          @fragments << Fragment.new(str, @current_node)
        end
      end

      def with_current_node(node, &block)
        begin
          saved= @current_node
          @current_node = node
          yield
        ensure
          @current_node = saved
        end
      end

      def generate_sourcemap(fragments)
      end

      class << self
        def generate(ast, opts = {})
          new(opts).generate(ast)
        end
      end
    end

    class GeneratedFragment
      include Assertions

      attr_reader :ast
      attr_reader :code

      def initialize(ast, children = [])
        assert_type AST::Node, ast
        assert_type_or_nil Array, children
        @children = children
        @ast = ast
      end

      # Walks the fragment tree in order with the following algorithm: If a
      # child is a string then call the block with the string and this ast node.
      # If the fragment is instead another GeneratedFragment, descend into that
      # tree by recursively calling the walk method and passing along the
      # iterator block.
      def walk(&block)
        @children.each do |child|
          if GeneratedFragment === child
            child.walk(&block)
          elsif String === child
            yield child, @ast
          end
        end
      end

      # FIXME to ast filename
      # FIXME add variable names
      def to_code_with_sourcemap
        filename = "somefile.rb"
        code = ""
        mappings = []
        location_index = LocationIndex.new

        walk do |chunk, ast|
          filename = ""
          name = ""
          generated = SourceMap::Offset.new(location_index.line, location_index.column)
          original = SourceMap::Offset.new(ast.location.start.line, ast.location.start.column)
          mappings << SourceMap::Mapping.new(filename, generated, original, name)

          # note: the << operator performs much better than += because it
          # mutates the string in place vs. copying the string each time which
          # would lead to an O(n^2) algorithm where n is the number of
          # characters in the generated code.
          code << chunk

          location_index.advance(chunk)
        end

        # Ensure mappings isn't empty: https://github.com/maccman/sourcemap/issues/11
        unless mappings.any?
          zero_offset = SourceMap::Offset.new(0,0)
          mappings << SourceMap::Mapping.new(filename, zero_offset, zero_offset)
        end

        sourcemap = SourceMap::Map.new(mappings)

        [code, sourcemap]
      end
    end
  end
end
