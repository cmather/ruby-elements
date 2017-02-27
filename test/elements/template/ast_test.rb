require "test_helper"
require "elements/template/ast"

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
  end
end
