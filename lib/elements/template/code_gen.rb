require "elements/core/assertions"
require "elements/template/generated_fragment"

module Elements
  module Template
    class CodeGen
      include  Core::Assertions

      attr_reader :result
      attr_reader :options
      attr_reader :data

      attr_accessor :indent

      def initialize(**options)
        @options = options
        @options[:indent] ||= "  "
        @data = {}
        @indent = ""
      end

      def generate(ast_node)
        assert_respond_to :generate, ast_node
        @result = ast_node.generate(self)
      end

      # Creates a new GeneratedFragment instance.
      def fragment(ast_node, &block)
        GeneratedFragment.new(self, ast_node).tap do |frag|
          yield frag if block_given?
        end
      end
    end
  end
end
