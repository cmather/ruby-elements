require "test_helper"
require "elements/template/lexer"

describe "Elements::Template::Lexer" do
  def assert_location_index(location_index, index:, line:, column:)
    assert_equal index, location_index.index, "@location_index.index is wrong"
    assert_equal line, location_index.line, "@location_index.line is wrong"
    assert_equal column, location_index.column, "@location_index.column is wrong"
  end

  def assert_token(input:, type:, value: input, start_state: :default, finish_state: start_state)
    lexer = Elements::Template::Lexer.new(input, state: start_state == :default ? nil : start_state)
    token = lexer.scan
    assert token, "no token"
    assert_equal token, lexer.lookahead, "lookahead not set to correct token"
    assert_equal type, token.type, "wrong token.type"
    assert_equal value, token.value, "wrong token.value"
    assert_equal finish_state, lexer.state, "wrong lexer finishing state"
  end

  describe "token" do
    it "creates token with correct location" do
      input = "one\ntwo"
      lexer = Elements::Template::Lexer.new(input)

      # test the initial location index
      location_index = lexer.instance_eval { @location_index }
      assert_location_index location_index, index: 0, line: 1, column: 0

      # make sure we get a token back
      token = lexer.instance_eval { @scanner.scan(/#{input}/); token(:ANY, input) }
      assert_instance_of Elements::Template::Token, token, "no token returned from token method"
      assert_equal :ANY, token.type, "wrong token type"
      assert_equal input, token.value, "wrong token value"

      # see if location was advanced
      location_index = lexer.instance_eval { @location_index }
      assert_location_index location_index, index: input.size, line: 2, column: 3
    end
  end

  describe "States::DEFAULT" do
    it "ANY" do
      assert_token(
        input: "test",
        type: :ANY
      )
    end

    it "TEMPLATE_OPEN" do
      assert_token(
        input: "<template",
        type: :TEMPLATE_OPEN,
        start_state: :default,
        finish_state: :tag_attributes
      )
    end
  end

  describe "States::TEMPLATE" do
    it "COMMENT" do
      assert_token(
        input: "<!-- my comment -->",
        value: "my comment",
        type: :COMMENT,
        start_state: :template
      )
    end

    it "TEMPLATE_OPEN" do
      assert_token(
        input: "<template",
        type: :TEMPLATE_OPEN,
        start_state: :template,
        finish_state: :template
      )
    end

    it "TEMPLATE_CLOSE" do
      assert_token(
        input: "</template>",
        type: :TEMPLATE_CLOSE,
        start_state: :template,
        finish_state: :default
      )
    end

    it "OPEN_CARET_FORWARD_SLASH" do
      assert_token(
        input: "</",
        type: :OPEN_CARET_FORWARD_SLASH,
        start_state: :template,
        finish_state: :tag_close
      )
    end

    it "OPEN_CARET" do
      assert_token(
        input: "<",
        type: :OPEN_CARET,
        start_state: :template,
        finish_state: :tag_name
      )
    end

    it "TEXT" do
      assert_token(
        input: "one\ntwo\nthree\tfour five",
        type: :TEXT,
        start_state: :template,
        finish_state: :template
      )
    end
  end

  describe "States::TAG_NAME" do
    it "TAG_NAMESPACE" do
      assert_token(
        input: "ns:tag",
        type: :TAG_NAMESPACE,
        value: "ns",
        start_state: :tag_name,
        finish_state: :tag_name
      )
    end

    it "ELEMENT_NAME" do
      assert_token(
        input: "div",
        type: :ELEMENT_NAME,
        start_state: :tag_name,
        finish_state: :tag_attributes
      )
    end

    it "VIEW_NAME" do
      assert_token(
        input: "Views::Home::Template",
        type: :VIEW_NAME,
        start_state: :tag_name,
        finish_state: :tag_attributes
      )
    end
  end

  describe "States::TAG_ATTRIBUTES" do
    it "ATTRIBUTE_NAME" do
      assert_token(
        input: "data-attribute",
        type: :ATTRIBUTE_NAME,
        start_state: :tag_attributes,
        finish_state: :tag_attributes
      )

      assert_token(
        input: "regular",
        type: :ATTRIBUTE_NAME,
        start_state: :tag_attributes,
        finish_state: :tag_attributes
      )
    end

    it "EQUALS" do
      assert_token(
        input: "=",
        type: :EQUALS,
        start_state: :tag_attributes,
        finish_state: :tag_attribute_value
      )
    end

    it "FORWARD_SLASH_CLOSE_CARET" do
      assert_token(
        input: "/>",
        type: :FORWARD_SLASH_CLOSE_CARET,
        start_state: :tag_attributes,
        finish_state: :default
      )
    end

    it "CLOSE_CARET" do
      assert_token(
        input: ">",
        type: :CLOSE_CARET,
        start_state: :tag_attributes,
        finish_state: :default
      )
    end
  end

  describe "States::TAG_ATTRIBUTE_VALUE" do
    it "ATTRIBUTE_VALUE_SINGLE_QUOTED_STRING" do
      assert_token(
        input: "'value'",
        value: "value",
        type: :ATTRIBUTE_VALUE,
        start_state: :tag_attribute_value,
        finish_state: :default
      )
    end

    it "ATTRIBUTE_VALUE_DOUBLE_QUOTED_STRING" do
      assert_token(
        input: '"value"',
        value: "value",
        type: :ATTRIBUTE_VALUE,
        start_state: :tag_attribute_value,
        finish_state: :default
      )
    end

    it "ATTRIBUTE_VALUE_HEXCHARS" do
      assert_token(
        input: "#333cc",
        type: :ATTRIBUTE_VALUE,
        start_state: :tag_attribute_value,
        finish_state: :default
      )
    end

    it "ATTRIBUTE_VALUE_PCTCHARS" do
      assert_token(
        input: "100%",
        type: :ATTRIBUTE_VALUE,
        start_state: :tag_attribute_value,
        finish_state: :default
      )
    end

    it "ATTRIBUTE_VALUE_CHARS" do
      assert_token(
        input: "one-two-123_/+,?=:;#ABC",
        type: :ATTRIBUTE_VALUE,
        start_state: :tag_attribute_value,
        finish_state: :default
      )
    end
  end

  describe "States::TAG_CLOSE" do
    it "TAG_NAMESPACE" do
      assert_token(
        input: "ns:div",
        value: "ns",
        type: :TAG_NAMESPACE,
        start_state: :tag_close,
        finish_state: :tag_close
      )
    end

    it "ELEMENT_NAME" do
      assert_token(
        input: "div",
        type: :ELEMENT_NAME,
        start_state: :tag_close,
        finish_state: :tag_close
      )
    end

    it "VIEW_NAME" do
      assert_token(
        input: "Views::Home",
        type: :VIEW_NAME,
        start_state: :tag_close,
        finish_state: :tag_close
      )
    end

    it "CLOSE_CARET" do
      assert_token(
        input: ">",
        type: :CLOSE_CARET,
        start_state: :tag_close,
        finish_state: :default
      )
    end
  end
end
