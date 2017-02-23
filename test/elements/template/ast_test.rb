require "test_helper"
require "elements/template/ast"

describe "Elements::Template::AST" do
  def create_document_ast(children = [])
    Elements::Template::AST::Document.new.tap do |document_ast|
      children.each { |child_node| document_ast << child_node }
    end
  end

  def create_attribute_ast(name, value = nil)
    name_ast = Elements::Template::AST::AttributeName.new(name)
    if value.nil?
      value_ast = nil
      boolean = true
    else
      value_ast = Elements::Template::AST::AttributeValue.new(value)
      boolean = false
    end

    Elements::Template::AST::Attribute.new(name_ast, value_ast, boolean)
  end

  def assign_attributes(ast, attributes)
    attributes.each do |attr_name, attr_value|
      ast.attributes << create_attribute_ast(attr_name, attr_value)
    end
  end

  def create_template_ast(attributes = {}, children = [])
    Elements::Template::AST::Template.new.tap do |template_ast|
      assign_attributes(template_ast, attributes)
      children.each { |child_node| template_ast << child_node }
    end
  end

  def create_element_ast(tagname, attributes = {}, children = [])
    re = /(?:(?<namespace>\w+):)?(?<tagname>\w+)/
    match = re.match(tagname)
    Elements::Template::AST::Element.new(match[:tagname], match[:namespace]).tap do |element_ast|
      assign_attributes(element_ast, attributes)
      children.each { |child| element_ast.children << child }
    end
  end

  def create_any_ast(value)
    Elements::Template::AST::Any.new(value)
  end

  def create_text_ast(value)
    Elements::Template::AST::Text.new(value)
  end

  def create_comment_ast(value)
    Elements::Template::AST::Comment.new(value)
  end

  def assert_preorder_traversal(expected, ast)
    assert_equal expected, ast.preorder.map { |node| node.class }, "wrong ast nodes in preorder traversal"
  end

  describe "Document" do
    it "should provide preorder iteration" do
      ast = create_document_ast([
        create_any_ast("require 'some/path/to/victory'"),
        create_template_ast({name: "MyTemplate"}, [create_text_ast("hello world")]),
        create_any_ast("footer")
      ])

      expected = [
        Elements::Template::AST::Document,
        Elements::Template::AST::Any,
        Elements::Template::AST::Template,
        Elements::Template::AST::AttributeCollection,
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
      ast = create_template_ast({name: "MyTemplate"}, [
        create_text_ast("hello world")
      ])

      expected = [
        Elements::Template::AST::Template,
        Elements::Template::AST::AttributeCollection,
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
      ast = create_element_ast("div", {id: "1", class: "css-class"}, [
        create_text_ast("hello"),
        create_element_ast("span", {}, [
          create_text_ast("world")
        ])
      ])

      expected = [
        Elements::Template::AST::Element,
        Elements::Template::AST::AttributeCollection,
        Elements::Template::AST::Attribute,
        Elements::Template::AST::AttributeName,
        Elements::Template::AST::AttributeValue,
        Elements::Template::AST::Attribute,
        Elements::Template::AST::AttributeName,
        Elements::Template::AST::AttributeValue,
        Elements::Template::AST::Text,
        Elements::Template::AST::Element,
        Elements::Template::AST::AttributeCollection,
        Elements::Template::AST::Text
      ]

      assert_preorder_traversal(expected, ast)
    end
  end

  describe "Attribute" do
    it "should provide preorder iteration" do
      ast = create_attribute_ast("class", "some-class")

      expected = [
        Elements::Template::AST::Attribute,
        Elements::Template::AST::AttributeName,
        Elements::Template::AST::AttributeValue
      ]

      assert_preorder_traversal(expected, ast)
    end
  end
end
