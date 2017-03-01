require "test_helper"
require "elements/template/ast"
require "elements/template/parser"
require "elements/template/generated_fragment"

describe "Elements::Template::GeneratedFragment" do
  def create_location(start, finish)
    Elements::Template::Location.new(
      Elements::Template::Position.new(*start),
      Elements::Template::Position.new(*finish)
    )
  end

  it "should work" do
    op_ast_class = Class.new(Elements::Template::AST::Node) do
      attr_reader :left, :right
      def initialize(left, right, location)
        super(location)
        @left = left
        @right = right
      end
    end

    term_ast_class = Class.new(Elements::Template::AST::Node) do
      attr_reader :value
      def initialize(value, **options)
        super(options)
        @value = value
      end
    end

    # build an ast tree for "2 + 3"

    # "2" is located at index: 0, line: 1, column: 0 to index: 1, line: 1,
    # column: 1
    left_term_ast = term_ast_class.new("2", location: create_location([0,1,0], [1,1,1]))

    # "3" is located from index: 4, line: 1, column: 4 to index: 5, line: 1,
    # column: 5
    right_term_ast = term_ast_class.new("3", location: create_location([4,1,4], [5,1,5]))

    op_ast = op_ast_class.new(left_term_ast, right_term_ast, location: create_location([0,1,0], [5,1,5]))

    # just generate the same tree as the source to make things simple
    frag = Elements::Template::GeneratedFragment.new(op_ast, [
      Elements::Template::GeneratedFragment.new(left_term_ast, ["2"]),
      " + ",
      Elements::Template::GeneratedFragment.new(right_term_ast, ["3"])
    ])

    code, sourcemap = frag.to_code_with_sourcemap()

    assert_equal "2 + 3", code, "wrong code"


    expected = [
      {generated: [1, 0], original: [1, 0]},
      {generated: [1, 1], original: [1, 0]},
      {generated: [1, 4], original: [1, 4]}
    ]

    actual = sourcemap.map do |mapping|
      {
        generated: [mapping.generated.line, mapping.generated.column],
        original: [mapping.original.line, mapping.original.column]
      }
    end

    assert_equal expected, actual, "wrong sourcemap mappings"
  end
end
