require "test_helper"
require "elements/vdom/api/server_dom"

describe "Elements::VDOM::API::ServerDOM" do
  before do
    @document = Elements::VDOM::API::ServerDOM::Document.new
  end

  it "create_element" do
    el = @document.create_element("div")
    el.id = "myid"
    assert el, "element not created"
    assert_equal "DIV", el.tag_name, "wrong tag name"
    assert_equal "myid", el.id, "wrong id"
    assert_equal @document, el.owner_document, "wrong owner doc"
  end

  it "create_element_ns" do
    el = @document.create_element_ns("mynamespace", "div")
    el.id = "myid"
    assert el, "element not created"
    assert_equal "DIV", el.tag_name, "wrong tag name"
    assert_equal "myid", el.id, "wrong id"
    assert_equal @document, el.owner_document, "wrong owner doc"
    assert_equal "mynamespace", el.namespace_uri, "wrong namespace"
  end

  it "create_text_node" do
    text = @document.create_text_node("hello")
    assert text, "text node not created"
    assert_equal "hello", text.text_content, "wrong text content"
    assert_equal @document, text.owner_document, "wrong owner doc"
  end

  it "append_child" do
    el = @document.create_element("body")
    @document.append_child(el)
    assert_equal el, @document.child_nodes[0], "el not appended"
  end

  it "insert_before" do
    el1 = @document.create_element("div")
    el1.id = "1"

    el2 = @document.create_element("div")
    el2.id = "2"

    el3 = @document.create_element("div")
    el3.id = "3"

    @document.append_child(el1)
    @document.append_child(el3)

    assert_equal @document.child_nodes[0], el1, "el1 not appended"
    assert_equal @document.child_nodes[1], el3, "el3 not appended"

    @document.insert_before(el2, el3)
    assert_equal @document.child_nodes[0], el1, "el1 not in right spot"
    assert_equal @document.child_nodes[1], el2, "el2 not in right spot"
    assert_equal @document.child_nodes[2], el3, "el3 not in right spot"

    # el1 prev and next
    assert_nil el1.previous_sibling, "wrong previous_sibling for el1"
    assert_equal el2, el1.next_sibling, "wrong next_sibling for el1"

    # el2 prev and next
    assert_equal el1, el2.previous_sibling, "wrong previous_sibling for el2"
    assert_equal el3, el2.next_sibling, "wrong next_sibling for el2"

    # el3 prev and next
    assert_equal el2, el3.previous_sibling, "wrong previous_sibling for el3"
    assert_nil el3.next_sibling, "wrong next_sibling for el3"
  end

  it "remove_child" do
    el1 = @document.create_element("div")
    el1.id = "1"

    el2 = @document.create_element("div")
    el2.id = "2"

    el3 = @document.create_element("div")
    el3.id = "3"

    @document.append_child(el1)
    @document.append_child(el2)
    @document.append_child(el3)

    assert_equal 3, @document.child_nodes.size, "elements not appended"

    # remove the middle element
    @document.remove_child(el2)

    # test linkages are unset and element removed
    assert_equal 2, @document.child_nodes.size, "element not removed"
    assert_nil el2.parent_node, "parent_node still set"
    assert_nil el2.previous_sibling, "previous_sibling still set"
    assert_nil el2.next_sibling, "next_sibling still set"

    # test remaining elements linked correctly
    assert_equal el3, el1.next_sibling, "wrong next_sibling for el1"
    assert_equal el1, el3.previous_sibling, "wrong previous_sibling for el3"
  end

  it "preorder enumeration with each" do
    el1 = @document.create_element("div")
    el1.id = "1"

    el2 = @document.create_element("div")
    el2.id = "2"

    el3 = @document.create_element("div")
    el3.id = "3"

    @document.append_child(el1)
    @document.append_child(el3)
    el1.append_child(el2)

    result = []
    @document.each do |node|
      result << node
    end

    assert_equal 4, result.size, "missing nodes in preorder enumeration"
  end

  it "parent_node" do
    el1 = @document.create_element("div")
    @document.append_child(el1)
    assert_equal @document, el1.parent_node, "wrong parent_node for el1"
  end

  it "next_sibling" do
    el1 = @document.create_element("div")
    el2 = @document.create_element("div")
    @document.append_child(el1)
    @document.append_child(el2)
    assert_equal el2, el1.next_sibling, "wrong next_sibling for el1"
  end

  it "tag_name" do
    el = @document.create_element("div")
    assert_equal "DIV", el.tag_name, "wrong tag_name for el"
  end

  it "text_content and set_text_content" do
    el1 = @document.create_element("div")

    # put a span with a child text node
    el2 = @document.create_element("span")
    el2.text_content = "hello"
    assert_equal 1, el2.child_nodes.size, "text not added as a child node"
    assert_equal "hello", el2.text_content, "wrong text_content for el2"
    el1.append_child(el2)

    # now append a text node to the top level div
    text = @document.create_text_node("world")
    el1.append_child(text)
    assert_equal text, el1.child_nodes[1], "text not not appended to div"

    # and see that the text_content is the concatenation of all the child text
    # nodes, including a preorder recursive descent into the child tree.
    assert_equal "helloworld", el1.text_content, "el1.text_content not correctly concatenating"
  end

  it "attributes direct access" do
    el = @document.create_element("div")
    el.attributes.must_be_kind_of Hash, "attributes should be a Hash"
    el.attributes["key"] = "value"
    el.attributes["key"].must_equal "value"
  end

  it "attributes getter and setter methods" do
    el = @document.create_element("div")
    el.set_attribute("key", "value")
    el.get_attribute("key").must_equal "value"
  end
end
