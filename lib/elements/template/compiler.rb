require "elements/core/assertions"
require "elements/template/parser"
require "elements/template/code_gen"

module Elements
  module Template
    class Compiler
      include Core::Assertions

      attr_reader :code
      attr_reader :sourcemap
      attr_reader :filename

      def initialize(**options)
        @options = options
      end

      def compile(io)
        # FIXME change api of parser to pass io to parse method
        ast_node = Parser.new(io, @options).parse
        codegen = CodeGen.new(@options)
        @fragment = codegen.generate(ast_node)
        @code, @sourcemap = @fragment.to_code_with_sourcemap
        @code
      end

      class << self
        def compile(io, **options)
          new(options).compile(io)
        end
      end
    end
  end
end
