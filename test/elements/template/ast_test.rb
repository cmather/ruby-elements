require "test_helper"
require "elements/template/ast"
require "elements/template/code_gen"

describe "Elements::Template::AST" do
  def document(children = [], options = {})
    Elements::Template::AST::Document.new(options).tap do |document_ast|
      children.each { |child_node| document_ast << child_node }
    end
  end

  def any(value, options = {})
    Elements::Template::AST::Any.new(value, options)
  end

  def attribute(name, value = nil, options = {})
    Elements::Template::AST::Attribute.new(
      Elements::Template::AST::AttributeName.new(name),
      value.nil? ? nil : Elements::Template::AST::AttributeValue.new(value),
      options
    )
  end

  def text(value, options = {})
    Elements::Template::AST::Text.new(value, options)
  end

  def template(attrs = {}, children = [], options = {})
    Elements::Template::AST::Template.new(options).tap do |node|
      assign_attributes(node, attrs)
      assign_children(node, children)
    end
  end

  def element(tagname, attributes = {}, children = [])
    re = /(?:(?<namespace>\w+):)?(?<tagname>\w+)/
    match = re.match(tagname)
    Elements::Template::AST::Element.new(match[:tagname], namespace: match[:namespace]).tap do |node|
      assign_attributes(node, attributes)
      assign_children(node, children)
    end
  end

  def assign_attributes(node, attributes)
    attributes.each do |name, value|
      node.attributes << attribute(name, value)
    end
  end

  def assign_children(node, children)
    children.each { |c| node.add(c) }
  end

  def assert_preorder_traversal(expected, ast)
    assert_equal expected, ast.preorder.map { |node| node.class }, "wrong ast nodes in preorder traversal"
  end

  describe "Any" do
    it "generates code" do
      ast = any("hello world")
      expected = "hello world"
      assert_equal expected, ast.generate.to_code()
    end
  end

  describe "Attribute" do
    it "should provide preorder iteration" do
      ast = attribute("class", "some-class")

      expected = [
        Elements::Template::AST::Attribute,
        Elements::Template::AST::AttributeName,
        Elements::Template::AST::AttributeValue
      ]

      assert_preorder_traversal(expected, ast)
    end

    it "generates code" do
      ast = attribute("id", "1")
      expected = '"id" => "1"'
      assert_equal expected, ast.generate.to_code()
    end
  end

  describe "AttributeName" do
    it "generates code" do
      ast = Elements::Template::AST::AttributeName.new("hello world")
      expected = "\"hello world\""
      assert_equal expected, ast.generate.to_code()
    end
  end

  describe "AttributeValue" do
    it "generates code" do
      ast = Elements::Template::AST::AttributeValue.new("hello world")
      expected = "\"hello world\""
      assert_equal expected, ast.generate.to_code()
    end
  end

  describe "Comment" do
    it "generates code" do
      ast = Elements::Template::AST::Comment.new("one\ntwo\nthree")
      expected = "# one\n# two\n# three"
      assert_equal expected, ast.generate.to_code()
    end
  end

  describe "Document" do
    it "should provide preorder iteration" do
      ast = document([
        any("require 'some/path/to/victory'"),
        template({name: "MyTemplate"}, [text("hello world")]),
        any("footer")
      ])

      expected = [
        Elements::Template::AST::Document,
        Elements::Template::AST::Any,
        Elements::Template::AST::Template,
        Elements::Template::AST::Attribute,
        Elements::Template::AST::AttributeName,
        Elements::Template::AST::AttributeValue,
        Elements::Template::AST::Text,
        Elements::Template::AST::Any
      ]

      assert_preorder_traversal(expected, ast)
    end

    it "generates code" do
      ast = document([
        any("require 'some/path/to/victory'\n\n"),
        template({name: "MyTemplate"}, [text("hello world")]),
        any("\nfooter")
      ])

      expected = <<-EOF.strip_heredoc
      require "elements/template"

      require 'some/path/to/victory'

      class MyTemplate < Elements::Template::Base
        def default_options
          {
            "name" => "MyTemplate"
          }
        end

        def children
          [
            vtext("hello world")
          ]
        end
      end
      footer
      EOF
      assert_equal expected.strip, ast.generate.to_code()
    end
  end

  describe "Element" do
    it "should provide preorder iteration" do
      ast = element("div", {id: "1", class: "css-class"}, [
        text("hello"),
        element("span", {}, [text("world")])
      ])

      expected = [
        Elements::Template::AST::Element,
        Elements::Template::AST::Attribute,
        Elements::Template::AST::AttributeName,
        Elements::Template::AST::AttributeValue,
        Elements::Template::AST::Attribute,
        Elements::Template::AST::AttributeName,
        Elements::Template::AST::AttributeValue,
        Elements::Template::AST::Text,
        Elements::Template::AST::Element,
        Elements::Template::AST::Text
      ]

      assert_preorder_traversal(expected, ast)
    end

    it "generates code" do
      ast = element("div", {id: "myid"}, [
        text("hello world")
      ])

      expected = <<-EOF.strip_heredoc
      vnode("div", {
        "id" => "myid"
      }, [
        vtext("hello world")
      ])
      EOF
      assert_equal expected.strip, ast.generate.to_code()
    end
  end

  describe "Template" do
    it "should provide preorder iteration" do
      ast = template({name: "MyTemplate"}, [text("hello world")])

      expected = [
        Elements::Template::AST::Template,
        Elements::Template::AST::Attribute,
        Elements::Template::AST::AttributeName,
        Elements::Template::AST::AttributeValue,
        Elements::Template::AST::Text
      ]

      assert_preorder_traversal(expected, ast)
    end

    it "generates class code" do
      ast = template({name: "TestTemplate", id: 5, "data-prop" => true}, [
        text("hello"),
        text("world")
      ])

      expected = <<-EOF.strip_heredoc
      class TestTemplate < Elements::Template::Base
        def default_options
          {
            "name" => "TestTemplate",
            "id" => "5",
            "data-prop" => "true"
          }
        end

        def children
          [
            vtext("hello"),
            vtext("world")
          ]
        end
      end
      EOF
      assert_equal expected.strip, ast.generate.to_code()
    end

    it "generates inline code" do
      ast = template({name: "TestTemplate", id: 5, "data-prop" => true}, [
        text("hello"),
        text("world")
      ], {inline: true})

      expected = <<-EOF.strip_heredoc
      Template.new({
        "name" => "TestTemplate",
        "id" => "5",
        "data-prop" => "true"
      }, [
        vtext("hello"),
        vtext("world")
      ])
      EOF
      assert_equal expected.strip, ast.generate.to_code()
    end
  end

  describe "Text" do
    it "generates code" do
      ast = Elements::Template::AST::Text.new("test value")
      codegen = Elements::Template::CodeGen.new
      frag = ast.generate(codegen)
      expected = 'vtext("test value")'
      assert_equal expected, frag.to_code
    end
  end
end
