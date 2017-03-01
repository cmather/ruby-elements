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

      def initialize(ast, chunks = [], **options)
        assert_type AST::Node, ast
        assert_type_or_nil Array, chunks
        @chunks = chunks
        @ast = ast
        @options = options
        @indent = options[:indent] || ""
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

      # Write one or more chunks to this fragment.
      def write(*chunks)
        chunks.each { |chunk| @chunks << chunk }
        self
      end

      # Write an indent followed by one or more chunks to this fragment.
      def indent(*chunks)
        @chunks << @indent
        write(chunks)
        self
      end

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
        reduce("") { |code, chunk| code << chunk }
      end
    end
  end
end
