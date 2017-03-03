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

  it "should generally work" do
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
    gen = Elements::Template::CodeGen.new
    frag = gen.fragment(op_ast)

    frag.write do
      gen.fragment(left_term_ast) do |child_frag|
        child_frag.write "2"
      end
    end

    frag.write " + "

    frag.write do
      gen.fragment(right_term_ast) do |child_frag|
        child_frag.write "3"
      end
    end

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

  it "indent" do
    gen = Elements::Template::CodeGen.new
    result = gen.fragment(Elements::Template::AST::Node.new) do |frag|
      frag.write "class MyClass\n"
      frag.indent do
        frag.indent "def hello_world; end\n"
      end
      frag.write "end"
    end

    expected = "class MyClass\n  def hello_world; end\nend"
    assert_equal expected, result.to_code
  end

  it "newline" do
    gen = Elements::Template::CodeGen.new
    result = gen.fragment(Elements::Template::AST::Node.new) do |frag|
      frag.write "1"
      frag.newline
      frag.write "2"
      frag.newline
      frag.write "3"
    end

    expected = "1\n2\n3"
    assert_equal expected, result.to_code
  end

  it "with_modules" do
    gen = Elements::Template::CodeGen.new
    result = gen.fragment(Elements::Template::AST::Node.new) do |frag|
      frag.with_modules(["Views", "Home"]) do
        frag.indent "class Template\n"
        frag.indent "end"
      end
    end

    expected = "module Views\n  module Home\n    class Template\n    end\n  end\nend"
    assert_equal expected, result.to_code
  end

  it "with_class" do
    gen = Elements::Template::CodeGen.new
    result = gen.fragment(Elements::Template::AST::Node.new) do |frag|
      frag.with_class("MyTemplate", superclass: "Elements::Template::Base") do
        frag.indent "def hello_world; end"
      end
    end

    expected = "class MyTemplate < Elements::Template::Base\n  def hello_world; end\nend"
    assert_equal expected, result.to_code
  end

  it "with_modules and with_class" do
    gen = Elements::Template::CodeGen.new
    result = gen.fragment(Elements::Template::AST::Node.new) do |frag|
      frag.with_modules(["Views", "Home"]) do
        frag.with_class("MyTemplate", superclass: "Elements::Template::Base") do
          frag.indent "def hello_world; end"
        end
      end
    end

    expected = <<-EOF.strip_heredoc
    module Views
      module Home
        class MyTemplate < Elements::Template::Base
          def hello_world; end
        end
      end
    end
    EOF

    assert_equal expected.strip, result.to_code
  end
end
