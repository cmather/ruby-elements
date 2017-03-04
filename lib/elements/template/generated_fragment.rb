require "sourcemap"
require "elements/template/ast"
require "elements/template/location"

module Elements
  module Template
    class GeneratedFragment
      include Enumerable
      include Assertions

      attr_reader :ast
      attr_reader :code

      def initialize(generator, ast)
        assert_type CodeGen, generator
        assert_type AST::Node, ast
        @chunks = []
        @ast = ast
        @generator = generator
      end

      # Generates a stack of modules and yields to the block indented to the
      # inside of the inner most module.
      def with_modules(modules, &block)
        add_module = -> (idx = 0) {
          if idx < modules.size
            indent("module").write(" ").write(modules[idx])
            newline
            indent do
              add_module.call(idx + 1)
            end
            newline
            indent("end")
          else
            yield
          end
        }

        add_module.call()
        self
      end

      # Generates a class and yields to the block which can add things to the
      # class before the class is ended.
      def with_class(class_name, **options, &block)
        indent("class").write(" ").write(class_name)
        write(" < ").write(options[:superclass]) unless options[:superclass].nil?
        newline
        indent do
          yield
        end
        newline
        indent("end")
        self
      end

      # Write an indent followed by one or more chunks to this fragment.
      def indent(*chunks, &block)
        if chunks.size > 0
          write @generator.indent
          write(*chunks)
          self
        else
          begin
            saved = @generator.indent
            @generator.indent += @generator.options[:indent]
            yield
            self
          ensure
            @generator.indent = saved
          end
        end
      end

      # Add a newline chunk.
      def newline
        write("\n")
      end

      # Add a quoted string.
      def quoted_string(str)
        write("\"#{str}\"")
      end


      # Write one or more chunks to this fragment.
      def write(*chunks, &block)
        if block_given?
          result = yield
          chunks += result.is_a?(Array) ? result : [result]
        end

        # just in case there's an array value on the chunks array (like when you
        # call generate on a NodeCollection) flatten the results into a single
        # array of strings and generated fragments.
        chunks.flatten.each do |chunk|
          assert_in_types [String, GeneratedFragment], chunk
          @chunks << chunk
        end

        self
      end

      alias_method :<<, :write

      def to_code_with_sourcemap
        mappings = []
        location_index = LocationIndex.new
        code = ""

        each do |chunk, ast|
          name = ""
          generated = SourceMap::Offset.new(location_index.line, location_index.column)
          original = SourceMap::Offset.new(ast.location.start.line, ast.location.start.column)
          mappings << SourceMap::Mapping.new(ast.filepath, generated, original, name)

          # note: the << operator performs much better than += because it
          # mutates the string in place vs. copying the string each time which
          # would lead to an O(n^2) algorithm where n is the number of
          # characters in the generated code.
          code << chunk

          # move the location index based on the chunk string value.
          location_index.advance(chunk)
        end

        # Ensure mappings isn't empty: https://github.com/maccman/sourcemap/issues/11
        unless mappings.any?
          zero_offset = SourceMap::Offset.new(0,0)
          mappings << SourceMap::Mapping.new(@ast.filepath, zero_offset, zero_offset)
        end

        sourcemap = SourceMap::Map.new(mappings)

        [code, sourcemap]
      end

      def to_code
        reduce("") do |code, args|
          # the first arg is the chunk and the second arg is the ast node. see
          # this class' implementation of 'each'.
          code << args[0]
        end
      end

      # Walks the fragment tree in order with the following algorithm: If a
      # child is a string then call the block with the string and this ast node.
      # If the fragment is instead another GeneratedFragment, descend into that
      # tree by recursively calling the walk method and passing along the
      # iterator block.
      def each(&block)
        @chunks.each do |chunk|
          if GeneratedFragment === chunk
            chunk.each(&block)
          elsif String === chunk
            yield chunk, @ast
          end
        end
      end
    end
  end
end
