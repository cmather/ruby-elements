module Elements
  module Template
    # This class stores compiled code strings in combination with their original AST nodes.
    # From this information we can generate a source map for the compiled AST
    # node.
    class Fragment
      attr_reader :ast
      attr_reader :code

      def initialize(code, ast)
        @code = code
        @ast = ast
      end

      def line
        ast.location.start.line
      end

      def column
        ast.location.start.column
      end
    end
  end
end
