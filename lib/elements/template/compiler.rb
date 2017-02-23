require "elements/assertions"
require "elements/template/parser"

# XXX remember to require the right files at the top, like the vdom stuff and
# the template and view.

module Elements
  module Template
    class Compiler
      include Assertions

      attr_reader :code
      attr_reader :sourcemap
      attr_reader :filename

      def initialize(io, options = {})
        assert_type Hash, options
        @parser = Parser.new(io, options)
        @options = options
        @sourcemap = nil
        @comments = []
        @result = nil
      end

      def compile
        ast = @parser.parse
        @result = ast.compile
        @result
      end
    end
  end
end
