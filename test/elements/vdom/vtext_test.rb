require "test_helper"
require "elements/vdom"

describe "Elements::VDOM::VText" do
  describe "initialize" do
    it "creates a vtext" do
      assert Elements::VDOM::VText.new("some text")
    end

    it "assigns a correct tag" do
      vnode = Elements::VDOM::VText.new("some text")
      vnode.tag.must_equal "text"
    end

    it "assigns text" do
      vnode = Elements::VDOM::VText.new("some text")
      vnode.text.must_equal "some text"
    end
  end

  describe "to_element" do
    it "creates a text node" do
      vtext = Elements::VDOM::VText.new("some text")
      el = vtext.to_element()
      el.must_be_kind_of Elements::VDOM::API::ServerDOM::Text
      el.text_content.must_equal "some text"
    end
  end
end
