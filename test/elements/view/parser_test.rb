require "test_helper"
require "elements/view/parser"

describe "Elements::View::Parser" do
  describe "parse_attribute" do
    it "parses boolean attribute" do
      source = 'focused'
      parser = Elements::View::Parser.new(source, state: :attributes)
      result = parser.instance_eval { parse_attribute }
      assert_instance_of Elements::View::AST::Attribute, result, "wrong ast type"
      assert_equal "focused", result.name.value, "wrong attribute name"
      assert_nil result.value, "wrong boolean attribute value"
      assert result.boolean?, "attribute should be boolean"
    end

    it "parses single quoted attribute" do
      source = "class='my-class'"
      parser = Elements::View::Parser.new(source, state: :attributes)
      result = parser.instance_eval { parse_attribute }
      assert_instance_of Elements::View::AST::Attribute, result, "wrong ast type"
      assert_equal "class", result.name.value, "wrong attribute name"
      assert_equal "my-class", result.value.value, "wrong attribute value"
    end

    it "parses double quoted attribute" do
      source = 'class="my-class"'
      parser = Elements::View::Parser.new(source, state: :attributes)
      result = parser.instance_eval { parse_attribute }
      assert_instance_of Elements::View::AST::Attribute, result, "wrong ast type"
      assert_equal "class", result.name.value, "wrong attribute name"
      assert_equal "my-class", result.value.value, "wrong attribute value"
    end

    it "parses random unquoted characters" do
      name = "someprop"
      value = "my-class_name./+,?=:;#0123abcABC"
      source = "#{name}=#{value}"
      parser = Elements::View::Parser.new(source, state: :attributes)
      result = parser.instance_eval { parse_attribute }
      assert_instance_of Elements::View::AST::Attribute, result, "wrong ast type"
      assert_equal name, result.name.value, "wrong attribute name"
      assert_equal value, result.value.value, "wrong attribute value"
    end

    it "parses unquoted hex characters" do
      name = "someprop"
      value = "#cccdef"
      source = "#{name}=#{value}"
      parser = Elements::View::Parser.new(source, state: :attributes)
      result = parser.instance_eval { parse_attribute }
      assert_instance_of Elements::View::AST::Attribute, result, "wrong ast type"
      assert_equal name, result.name.value, "wrong attribute name"
      assert_equal value, result.value.value, "wrong attribute value"
    end

    it "parses unquoted percent characters" do
      name = "someprop"
      value = "100%"
      source = "#{name}=#{value}"
      parser = Elements::View::Parser.new(source, state: :attributes)
      result = parser.instance_eval { parse_attribute }
      assert_instance_of Elements::View::AST::Attribute, result, "wrong ast type"
      assert_equal name, result.name.value, "wrong attribute name"
      assert_equal value, result.value.value, "wrong attribute value"
    end

    it "consumes whitespace" do
      name = "someprop"
      value = "100%"
      source = "#{name}   \t =   \t '#{value}'"
      parser = Elements::View::Parser.new(source, state: :attributes)
      result = parser.instance_eval { parse_attribute }
      assert_instance_of Elements::View::AST::Attribute, result, "wrong ast type"
      assert_equal name, result.name.value, "wrong attribute name"
      assert_equal value, result.value.value, "wrong attribute value"
    end
  end

  describe "parse_attributes" do
    it "parses multiple attributes" do
      source = "name1='value1' name2 = \"value2\"   \t name3 = 100%  name4"
      parser = Elements::View::Parser.new(source, state: :attributes)
      result = parser.instance_eval { parse_attributes }
      assert_instance_of Array, result, "expected array"
      expected = [["name1", "value1"], ["name2", "value2"], ["name3", "100%"],["name4", nil]]
      actual = result.map { |attr| [attr.name.value, attr.value && attr.value.value] }
      assert_equal expected, actual, "wrong attributes"
    end
  end

  describe "parse_any" do
    it "should parse anything in default state" do
      io = "anything goes require 'hello/world'; end"
      parser = Elements::View::Parser.new(io, state: :default)
      result = parser.instance_eval { parse_any }
      assert_instance_of Elements::View::AST::Any, result, "wrong ast node"
    end

    it "should add any as child to document node" do
      doc_node = Elements::View::AST::Document.new
      io = "anything goes require 'hello/world'; end"
      parser = Elements::View::Parser.new(io, state: :default)
      parser.instance_eval { @stack.push(doc_node) }
      result = parser.instance_eval { parse_any }
      assert_instance_of Elements::View::AST::Any, result, "wrong ast node"
      assert_equal doc_node, result.parent, "wrong parent"
      assert_equal result, doc_node.children.first, "not added to children of parent node"
    end

    it "should correctly set location" do
      input = "anything goes require 'hello/world'; end"
      parser = Elements::View::Parser.new(input, state: :default)
      result = parser.instance_eval { parse_any }

      assert result, "no ast node result from parse_any"
      assert_equal 0, result.location.start.index, "wrong start index"
      assert_equal 0, result.location.start.column, "wrong start column"
      assert_equal 1, result.location.start.line, "wrong start line"
      assert_equal input.size, result.location.finish.index, "wrong finish index"
      assert_equal input.size, result.location.finish.column, "wrong finish column"
      assert_equal 1, result.location.finish.line, "wrong finish line"
    end
  end

  describe "parse_comment" do
    it "should parse comment in template state" do
      comment = "test comment"
      io = "<!-- #{comment} -->"
      parser = Elements::View::Parser.new(io, state: :template)
      result = parser.instance_eval { parse_comment }
      assert_instance_of Elements::View::AST::Comment, result, "wrong comment ast node"
      assert_equal comment, result.value, "wrong comment value"
    end

    it "should parse comment in template state no spaces" do
      comment = "test comment"
      io = "<!--#{comment}-->"
      parser = Elements::View::Parser.new(io, state: :template)
      result = parser.instance_eval { parse_comment }
      assert_instance_of Elements::View::AST::Comment, result, "wrong comment ast node"
      assert_equal comment, result.value, "wrong comment value"
    end

    it "should add comment as child to template node" do
      template_node = Elements::View::AST::Template.new
      io = "<!-- test comment -->"
      parser = Elements::View::Parser.new(io, state: :template)
      parser.instance_eval { @stack.push(template_node) }
      result = parser.instance_eval { parse_comment }
      assert result, "no comment ast node"
      assert_equal template_node, result.parent
      assert_equal template_node.children[0], result, "comment not added as child to template"
    end

    it "should add comment as child to element node" do
      parent_node = Elements::View::AST::Element.new("div")
      io = "<!-- test comment -->"
      parser = Elements::View::Parser.new(io, state: :template)
      parser.instance_eval { @stack.push(parent_node) }
      result = parser.instance_eval { parse_comment }
      assert result, "no comment ast node"
      assert_equal parent_node, result.parent
      assert_equal parent_node.children[0], result, "comment not added as child to element"
    end

    it "should add comment as child to view node" do
      parent_node = Elements::View::AST::View.new("MyView")
      io = "<!-- test comment -->"
      parser = Elements::View::Parser.new(io, state: :template)
      parser.instance_eval { @stack.push(parent_node) }
      result = parser.instance_eval { parse_comment }
      assert result, "no comment ast node"
      assert_equal parent_node, result.parent
      assert_equal parent_node.children[0], result, "comment not added as child to view"
    end

    it "should correctly set location" do
      comment = "test comment"
      input = "<!-- #{comment} -->"
      parser = Elements::View::Parser.new(input, state: :template)
      result = parser.instance_eval { parse_comment }

      assert result, "no ast node result from parse_comment"
      assert_equal 0, result.location.start.index, "wrong start index"
      assert_equal 0, result.location.start.column, "wrong start column"
      assert_equal 1, result.location.start.line, "wrong start line"
      assert_equal input.size, result.location.finish.index, "wrong finish index"
      assert_equal input.size, result.location.finish.column, "wrong finish column"
      assert_equal 1, result.location.finish.line, "wrong finish line"
    end
  end

  describe "parse_text" do
    it "should parse text in template state" do
      input = "some text for you"
      parser = Elements::View::Parser.new(input, state: :template)
      result = parser.instance_eval { parse_text }
      assert_instance_of Elements::View::AST::Text, result, "wrong comment ast node"
      assert_equal input, result.value, "wrong ast node value"
    end

    it "should add text as child to template node" do
      template_node = Elements::View::AST::Template.new
      input = "some text for you"
      parser = Elements::View::Parser.new(input, state: :template)
      parser.instance_eval { @stack.push(template_node) }
      result = parser.instance_eval { parse_text }
      assert result, "no ast node"
      assert_equal template_node, result.parent
      assert_equal template_node.children[0], result, "not added as child to template"
    end

    it "should add text as child to element node" do
      parent_node = Elements::View::AST::Element.new("div")
      input = "some text for you"
      parser = Elements::View::Parser.new(input, state: :template)
      parser.instance_eval { @stack.push(parent_node) }
      result = parser.instance_eval { parse_text }
      assert result, "no ast node"
      assert_equal parent_node, result.parent
      assert_equal parent_node.children[0], result, "not added as child to element"
    end

    it "should add text as child to view node" do
      parent_node = Elements::View::AST::View.new("MyView")
      input = "some text for you"
      parser = Elements::View::Parser.new(input, state: :template)
      parser.instance_eval { @stack.push(parent_node) }
      result = parser.instance_eval { parse_text }
      assert result, "no ast node"
      assert_equal parent_node, result.parent
      assert_equal parent_node.children[0], result, "not added as child to view"
    end

    it "should correctly set location" do
      input = "some text for you"
      parser = Elements::View::Parser.new(input, state: :template)
      result = parser.instance_eval { parse_text }

      assert result, "no ast node result from parse_text"
      assert_equal 0, result.location.start.index, "wrong start index"
      assert_equal 0, result.location.start.column, "wrong start column"
      assert_equal 1, result.location.start.line, "wrong start line"
      assert_equal input.size, result.location.finish.index, "wrong finish index"
      assert_equal input.size, result.location.finish.column, "wrong finish column"
      assert_equal 1, result.location.finish.line, "wrong finish line"
    end
  end

  describe "parse_open_tag" do
    it "should parse element" do
      input = "<div>"
      parser = Elements::View::Parser.new(input, state: :template)
      result = parser.instance_eval { parse_open_tag }
      assert_instance_of Elements::View::AST::Element, result, "wrong tag ast node"
      assert_equal "div", result.name, "wrong tag name"
      assert_equal 1, parser.stack_size, "wrong stack size"
    end

    it "should parse namespace" do
      input = "<ns:div>"
      parser = Elements::View::Parser.new(input, state: :template)
      result = parser.instance_eval { parse_open_tag }
      assert_instance_of Elements::View::AST::Element, result, "wrong tag ast node"
      assert_equal "div", result.name, "wrong tag name"
      assert_equal "ns", result.namespace, "wrong tag namespace"
      assert_equal 1, parser.stack_size, "wrong stack size"
    end

    it "should parse view" do
      input = "<MyModule::MyView>"
      parser = Elements::View::Parser.new(input, state: :template)
      result = parser.instance_eval { parse_open_tag }
      assert_instance_of Elements::View::AST::View, result, "wrong tag ast node"
      assert_equal "MyModule::MyView", result.name, "wrong tag name"
      assert_equal 1, parser.stack_size, "wrong stack size"
    end

    it "should autoclose tags when needed" do
      input = "<li>"
      parser = Elements::View::Parser.new(input, state: :template)
      previous_li = Elements::View::AST::Element.new("li")
      parser.instance_eval { @stack.push(previous_li) }

      can_auto_close_tag_stub = lambda do |prev_tag_name, new_tag_name|
        assert_equal "li", prev_tag_name, "wrong prev_tag_name in can_auto_close_tag?"
        assert_equal "li", new_tag_name, "wrong new_tag_name in can_auto_close_tag?"
        true
      end

      parser.stub :can_auto_close_tag?, can_auto_close_tag_stub do
        result = parser.instance_eval { parse_open_tag }
        assert result, "no parse result"
        assert_equal 1, parser.stack_size, "prev tag not autoclosed and is still on stack"
      end
    end

    it "should add tag as child to last stack node" do
      input = "<li>"
      parser = Elements::View::Parser.new(input, state: :template)
      ul_node = Elements::View::AST::Element.new("ul")
      parser.instance_eval { @stack.push(ul_node) }

      can_auto_close_tag_stub = lambda do |prev_tag_name, new_tag_name|
        assert_equal "ul", prev_tag_name, "wrong prev_tag_name in can_auto_close_tag?"
        assert_equal "li", new_tag_name, "wrong new_tag_name in can_auto_close_tag?"
        false
      end

      parser.stub :can_auto_close_tag?, can_auto_close_tag_stub do
        result = parser.instance_eval { parse_open_tag }
        assert result, "no parse result"
        assert_equal 2, parser.stack_size, "wrong parser stack size"
        assert_equal ul_node, result.parent, "wrong parent"
        assert_equal result, ul_node.children.first, "wrong child"
      end
    end

    it "should parse element attributes" do
      input = "<div id='idval' class=\"cssval\" data-key=dataval>"
      parser = Elements::View::Parser.new(input, state: :template)
      result = parser.instance_eval { parse_open_tag }
      assert_instance_of Elements::View::AST::Element, result, "wrong tag ast node"

      expected = [
        ["id", "idval"],
        ["class", "cssval"],
        ["data-key", "dataval"]
      ]

      assert_equal expected, result.attributes.map { |a| [a.name.value, a.value.value] }, "wrong attributes"
    end

    it "should parse view attributes" do
      input = "<MyNs::MyView id='idval' class=\"cssval\" data-key=dataval>"
      parser = Elements::View::Parser.new(input, state: :template)
      result = parser.instance_eval { parse_open_tag }
      assert_instance_of Elements::View::AST::View, result, "wrong tag ast node"

      expected = [
        ["id", "idval"],
        ["class", "cssval"],
        ["data-key", "dataval"]
      ]

      assert_equal expected, result.attributes.map { |a| [a.name.value, a.value.value] }, "wrong attributes"
    end

    it "should not push void tags onto stack" do
      input = "<br>"
      parser = Elements::View::Parser.new(input, state: :template)

      # we'll stub the void_tag? method to ensure that this tag is considered
      # voidable. the void_tag? method is in the TagHelpers module where the
      # list of associated tags are.
      void_tag_stub = lambda do |tag_name|
        assert_equal "br", tag_name, "wrong tag name to void_tag?(tag_name) method call"
        true
      end

      parser.stub :void_tag?, void_tag_stub do
        parser.instance_eval { parse_open_tag }
        assert_equal 0, parser.stack_size, "void element should not have been pushed onto parser stack"
      end
    end

    it "should not push self closing tags onto stack" do
      input = "<div/>"
      parser = Elements::View::Parser.new(input, state: :template)

      # we'll stub the void_tag? method to ensure that this tag is considered
      # voidable. the void_tag? method is in the TagHelpers module where the
      # list of associated tags are.
      void_tag_stub = lambda do |tag_name|
        assert_equal "div", tag_name, "wrong tag name to void_tag?(tag_name) method call"
        false
      end

      parser.stub :void_tag?, void_tag_stub do
        parser.instance_eval { parse_open_tag }
        assert_equal 0, parser.stack_size, "self closing element should not have been pushed onto parser stack"
      end
    end

    it "should correctly set location on single line tag" do
      input = "<div>"
      parser = Elements::View::Parser.new(input, state: :template)
      result = parser.instance_eval { parse_open_tag }
      assert result, "no ast node result"

      assert_equal 0, result.location.start.index, "wrong start index"
      assert_equal 0, result.location.start.column, "wrong start column"
      assert_equal 1, result.location.start.line, "wrong start line"

      assert_equal input.size, result.location.finish.index, "wrong finish index"
      assert_equal input.size, result.location.finish.column, "wrong finish column"
      assert_equal 1, result.location.finish.line, "wrong finish line"
    end

    it "should correctly set location on multiline tag" do
      input = "<div \n\tattr1='val1'\n\tattr2='val2'>"
      parser = Elements::View::Parser.new(input, state: :template)
      result = parser.instance_eval { parse_open_tag }
      assert result, "no ast node result"

      assert_equal 0, result.location.start.index, "wrong start index"
      assert_equal 0, result.location.start.column, "wrong start column"
      assert_equal 1, result.location.start.line, "wrong start line"

      assert_equal input.size, result.location.finish.index, "wrong finish index"
      # note: 14 is the size of \tattr2='val2'
      assert_equal 14, result.location.finish.column, "wrong finish column"
      assert_equal 3, result.location.finish.line, "wrong finish line"
    end
  end

  describe "parse_close_tag" do
    it "should parse a close element tag" do
      open_node = Elements::View::AST::Element.new("div")
      input = "</div>"
      parser = Elements::View::Parser.new(input, state: :template)
      parser.instance_eval { @stack.push(open_node) }
      result = parser.instance_eval { parse_close_tag }
      assert_equal open_node, result, "wrong ast node"
      assert_equal 0, parser.stack_size, "open tag not popped from stack"
    end

    it "should parse a close element tag with namespace" do
      open_node = Elements::View::AST::Element.new("div", "ns")
      input = "</ns:div>"
      parser = Elements::View::Parser.new(input, state: :template)
      parser.instance_eval { @stack.push(open_node) }
      result = parser.instance_eval { parse_close_tag }
      assert_equal open_node, result, "wrong ast node"
      assert_equal 0, parser.stack_size, "open tag not popped from stack"
    end

    it "should parse a close view tag" do
      open_node = Elements::View::AST::View.new("MyModule::MyView")
      input = "</MyModule::MyView>"
      parser = Elements::View::Parser.new(input, state: :template)
      parser.instance_eval { @stack.push(open_node) }
      result = parser.instance_eval { parse_close_tag }
      assert_equal open_node, result, "wrong ast node"
      assert_equal 0, parser.stack_size, "open tag not popped from stack"
    end

    it "should autoclose previous tag if needed" do
      open_node = Elements::View::AST::Element.new("ul")
      autoclose_node = Elements::View::AST::Element.new("li")
      input = "</ul>"
      parser = Elements::View::Parser.new(input, state: :template)
      parser.instance_eval { @stack.push(open_node); @stack.push(autoclose_node) }

      can_auto_close_tag_stub = lambda do |tag_name|
        assert_equal "li", tag_name, "wrong tag_name to can_auto_close_tag? method"
        true
      end

      parser.stub :can_auto_close_tag?, can_auto_close_tag_stub do
        result = parser.instance_eval { parse_close_tag }
        assert_equal open_node, result, "wrong ast node"
        assert_equal 0, parser.stack_size, "open tag and autoclose tag not popped from stack"
      end
    end

    it "should raise error if no start tag found" do
      input = "</div>"
      parser = Elements::View::Parser.new(input, state: :template)

      assert_raises Elements::View::SyntaxError do
        parser.instance_eval { parse_close_tag }
      end
    end

    it "should correctly update location of start node" do
      input = "<div></div>"
      parser = Elements::View::Parser.new(input, state: :template)

      # first get the open tag on the stack with the right position
      result = parser.instance_eval { parse_open_tag }
      assert_equal 1, parser.stack_size, "open tag not on stack"

      # the initial location should just be the start <div> tag.
      assert_equal 0, result.location.start.index, "wrong start index"
      assert_equal 0, result.location.start.column, "wrong start column"
      assert_equal 1, result.location.start.line, "wrong start line"
      assert_equal "<div>".size, result.location.finish.index, "wrong finish index"
      assert_equal "<div>".size, result.location.finish.column, "wrong finish column"
      assert_equal 1, result.location.finish.line, "wrong finish line"

      # now parse the close tag
      result = parser.instance_eval { parse_close_tag }

      # and the location finish should have been updated to the </div> close tag
      assert_equal 0, result.location.start.index, "wrong start index"
      assert_equal 0, result.location.start.column, "wrong start column"
      assert_equal 1, result.location.start.line, "wrong start line"
      assert_equal input.size, result.location.finish.index, "wrong finish index"
      assert_equal input.size, result.location.finish.column, "wrong finish column"
      assert_equal 1, result.location.finish.line, "wrong finish line"
    end
  end

  describe "parse_document" do
    it "should parse an empty document" do
      input = ""
      parser = Elements::View::Parser.new(input, state: :default)
      result = parser.parse_document
      assert_instance_of Elements::View::AST::Document, result, "wrong ast node"
    end

    it "should parse content outside of templates" do
      input = "random content require 'some/path'"
      parser = Elements::View::Parser.new(input, state: :default)
      result = parser.parse_document
      assert_instance_of Elements::View::AST::Document, result, "wrong ast node"
      assert_equal 1, result.children.size, "any node not added to document children"
      assert_instance_of Elements::View::AST::Any, result.children[0], "expected AST::Any node"
      assert_equal input, result.children[0].value, "wrong AST::Any node value in document children"
    end

    it "should parse templates" do
      input = "<template></template><template></template>"
      parser = Elements::View::Parser.new(input, state: :default)
      result = parser.parse_document
      assert_instance_of Elements::View::AST::Document, result, "wrong ast node"
      assert_equal 2, result.children.size, "should be two templates in document children"
      assert_instance_of Elements::View::AST::Template, result.children[0], "wrong ast node"
      assert_instance_of Elements::View::AST::Template, result.children[1], "wrong ast node"
    end

    it "should parse mixed content" do
      input = "before<template></template>middle<template></template>after"
      parser = Elements::View::Parser.new(input, state: :default)
      result = parser.parse_document
      assert_instance_of Elements::View::AST::Document, result, "wrong ast node"
      assert_equal 5, result.children.size, "wrong children size"

      expected = [
        Elements::View::AST::Any,
        Elements::View::AST::Template,
        Elements::View::AST::Any,
        Elements::View::AST::Template,
        Elements::View::AST::Any
      ]

      assert_equal expected, result.children.map { |n| n.class }, "wrong ast nodes in children"
    end

    it "should set correct location" do
      input = "before<template></template>middle<template></template>after"
      parser = Elements::View::Parser.new(input, state: :default)
      result = parser.parse_document
      assert_instance_of Elements::View::AST::Document, result, "wrong ast node"
      assert_equal 5, result.children.size, "wrong children size"

      assert_equal 0, result.location.start.index, "wrong start index"
      assert_equal 0, result.location.start.column, "wrong start column"
      assert_equal 1, result.location.start.line, "wrong start line"
      assert_equal input.size, result.location.finish.index, "wrong finish index"
      assert_equal input.size, result.location.finish.column, "wrong finish column"
      assert_equal 1, result.location.finish.line, "wrong finish line"
    end
  end

  describe "parse_template_tag" do
    it "should parse simple template" do
      input = "<template></template>"
      parser = Elements::View::Parser.new(input, state: :default)
      result = parser.instance_eval { parse_template_tag }
      assert_instance_of Elements::View::AST::Template, result, "wrong ast node"
    end

    it "should parse template attributes" do
      input = "<template attr1='val1' attr2=val2 attr3=\"val3\"></template>"
      parser = Elements::View::Parser.new(input, state: :default)
      result = parser.instance_eval { parse_template_tag }
      assert_instance_of Elements::View::AST::Template, result, "wrong ast node"
      expected = [["attr1", "val1"], ["attr2", "val2"], ["attr3", "val3"]]
      assert_equal expected, result.attributes.map { |n| [n.name.value, n.value.value] }, "wrong attributes"
    end

    it "should parse template children" do
      input = "<template><div></div><div></div></template>"
      parser = Elements::View::Parser.new(input, state: :default)
      result = parser.instance_eval { parse_template_tag }
      assert_instance_of Elements::View::AST::Template, result, "wrong ast node"
      assert_equal 2, result.children.size, "wrong children size"
    end
  end

  describe "miscl input" do
    it "any content with one template" do
      input = <<-EOF
        require "some/path/to.css"

        class Bogus
        end

        <template name="MyTemplate">
          <h1>Title</h1>

          <p>
            Some description for you.
          </p>
        </template>
      EOF

      parser = Elements::View::Parser.new(input)
      result = parser.parse
      assert result, "no ast result"
    end

    it "any content with two templates" do
      input = <<-EOF
        require "some/path/to.css"

        class Bogus
        end

        <template name="One">
          <h1>Title</h1>

          <p>
            Some description for you.
          </p>
        </template>

        <template name="Two">
          <h1>Title</h1>

          <p>
            Some description for you.
          </p>
        </template>
      EOF

      parser = Elements::View::Parser.new(input)
      result = parser.parse
      assert result, "no ast result"
    end

    it "self closing tags" do
      input = <<-EOF
        <template name="One">
          <h1>Title</h1>

          <ul>
            <li>One
            <li>Two
            <li>Three
          </ul>
        </template>
      EOF

      parser = Elements::View::Parser.new(input.strip)
      result = parser.parse
      assert result, "no ast result"
    end
  end
end
