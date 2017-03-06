require "test_helper"
require "elements/vdom"

describe "Elements::VDOM::VNode" do
  include Elements::VDOM::Helpers

  before do
    @document = Elements::VDOM::API::ServerDOM::Document.new
    @container = @document.create_element("div")
    @container.set_attribute("id", "container")
  end

  describe "initialize" do
    it "creates a vnode" do
      assert Elements::VDOM::VNode.new("div")
    end

    it "assigns a tag" do
      vnode = Elements::VDOM::VNode.new("div")
      vnode.tag.must_equal "div"
    end

    it "assigns a key" do
      vnode = Elements::VDOM::VNode.new("div", key: "key")
      vnode.key.must_equal "key"
    end
  end

  describe "classes" do
    it "adds a css class" do
      node = vnode("div")
      node.class("myclass")
      node.classes.size.must_equal 1, "css classes wrong size"
      assert node.classes.include?("myclass"), "css class not applied"
    end

    it "doesn't add an empty css class" do
      node = vnode("div")
      node.class(nil)
      node.classes.size.must_equal 0, "nil shouldn't be added to css classes"
      node.class("")
      node.classes.size.must_equal 0, "empty string shouldn't be added to css classes"
    end

    it "adds multiple css classes" do
      node = vnode("div")
      node.class(nil)
      node.classes.size.must_equal 0, "nil shouldn't be added to css classes"
      node.class("")
      node.classes.size.must_equal 0, "empty string shouldn't be added to css classes"
    end
  end

  describe "events" do
    it "adds event handlers" do
      node = vnode("div")
      handler = lambda {}
      opts = {capture: true}
      node.event("click", handler, opts)
      evt = node.events["click"]
      assert_instance_of Hash, evt, "click event not registered"
      assert_equal "click", evt[:key], "click event key not set"
      assert_equal handler, evt[:handler], "click event handler not set"
      assert_equal opts[:capture], evt[:opts][:capture], "click event opts not set"
    end
  end

  describe "to_html" do
    it "should return an html string" do
      node = vnode("ul").children([
        vnode("li").child("One"),
        vnode("li").child("Two"),
        vnode("li").child("Three"),
      ])

      actual = node.to_html
      expected = "<ul><li>One</li><li>Two</li><li>Three</li></ul>"
      assert_equal expected, actual, "wrong html string"
    end

    it "can pretty print an html string" do
      node = vnode("ul").children([
        vnode("li").child("One"),
        vnode("li").child("Two"),
        vnode("li").child("Three"),
      ])

      indent = "\s\s"
      actual = node.to_html(pretty: true, indent_with: indent)
      expected = [
        "<ul>\n",
        "#{indent}<li>\n",
        "#{indent * 2}One\n",
        "#{indent}</li>\n",
        "#{indent}<li>\n",
        "#{indent * 2}Two\n",
        "#{indent}</li>\n",
        "#{indent}<li>\n",
        "#{indent * 2}Three\n",
        "#{indent}</li>\n",
        "</ul>\n"
      ].join

      assert_equal expected, actual, "wrong html string"
    end

    it "can pretty print an html string with starting indent" do
      node = vnode("ul").children([
        vnode("li").child("One"),
        vnode("li").child("Two"),
        vnode("li").child("Three"),
      ])

      indent_with = "\s\s"
      start_indent = 2
      actual = node.to_html(pretty: true, indent_with: indent_with, start_indent: start_indent)

      indent = -> (amt) { indent_with * start_indent  + indent_with * amt }
      expected = [
        "<ul>",
        "#{indent[1]}<li>",
        "#{indent[2]}One",
        "#{indent[1]}</li>",
        "#{indent[1]}<li>",
        "#{indent[2]}Two",
        "#{indent[1]}</li>",
        "#{indent[1]}<li>",
        "#{indent[2]}Three",
        "#{indent[1]}</li>",
        "#{indent[0]}</ul>\n"
      ].join("\n")

      expected.lstrip.must_equal(actual, "wrong html string")
    end
  end

  describe "to_element" do
    it "creates a dom element" do
      queue = []
      vnode = Elements::VDOM::VNode.new("div", key: "key")
      el = vnode.to_element(queue)
      el.must_be_kind_of Elements::VDOM::API::ServerDOM::Element
      el.tag_name.must_equal "DIV"
      el.get_attribute("data-vnode-key").must_equal "key"

      queue.size.must_equal 1
      queue.first.element.must_equal el
      queue.first.vnode.must_equal vnode
    end

    it "creates a dom element with children" do
      queue = []
      parent = Elements::VDOM::VNode.new("div", key: "parent")
      child1 = Elements::VDOM::VNode.new("div", key: "child1")
      child2 = Elements::VDOM::VNode.new("div", key: "child2")
      parent.children << child1
      parent.children << child2
      el = parent.to_element(queue)

      queue = queue.map(&:vnode)
      queue.must_equal [child1, child2, parent], "wrong insert queue"

      el.must_be_kind_of Elements::VDOM::API::ServerDOM::Element, "wrong type"
      el.tag_name.must_equal "DIV", "wrong tag"
      el.get_attribute("data-vnode-key").must_equal "parent", "wrong key"

      el.child_nodes[0].must_be_kind_of Elements::VDOM::API::ServerDOM::Element, "wrong type"
      el.child_nodes[0].tag_name.must_equal "DIV", "wrong tag"
      el.child_nodes[0].get_attribute("data-vnode-key").must_equal "child1", "wrong key"

      el.child_nodes[1].must_be_kind_of Elements::VDOM::API::ServerDOM::Element, "wrong type"
      el.child_nodes[1].tag_name.must_equal "DIV", "wrong tag"
      el.child_nodes[1].get_attribute("data-vnode-key").must_equal "child2", "wrong key"
    end

    it "creates a dom element with text children" do
      queue = []
      parent = Elements::VDOM::VNode.new("div", key: "parent")
      child1 = Elements::VDOM::VText.new("text1")
      child2 = Elements::VDOM::VText.new("text2")
      parent.children << child1
      parent.children << child2
      el = parent.to_element(queue)

      el.must_be_kind_of Elements::VDOM::API::ServerDOM::Element, "wrong type"
      el.tag_name.must_equal "DIV", "wrong tag"
      el.get_attribute("data-vnode-key").must_equal "parent", "wrong key"

      el.child_nodes[0].must_be_kind_of Elements::VDOM::API::ServerDOM::Text, "wrong type"
      el.child_nodes[0].text_content.must_equal "text1", "wrong text"

      el.child_nodes[1].must_be_kind_of Elements::VDOM::API::ServerDOM::Text, "wrong type"
      el.child_nodes[1].text_content.must_equal "text2", "wrong text"
    end

    it "triggers the right events" do
      parent = Elements::VDOM::VNode.new("div", key: "parent")
      child1 = Elements::VDOM::VNode.new("div", key: "child1")
      child2 = Elements::VDOM::VNode.new("div", key: "child2")
      parent.children << child1
      parent.children << child2

      with_event_log do |log|
        element = parent.to_element()

        expected_events = [
          { args: [Elements::VDOM::VNode::Events::CREATE, element.child_nodes[0]], self: child1 },
          { args: [Elements::VDOM::VNode::Events::CREATE, element.child_nodes[1]], self: child2 },
          { args: [Elements::VDOM::VNode::Events::CREATE, element],                self: parent }
        ]

        log.must_equal(expected_events, "wrong event log")
      end
    end
  end

  describe "append_to" do
    it "appends the vnode to an existing element" do
      parent = Elements::VDOM::VNode.new("div", key: "parent")
      child1 = Elements::VDOM::VNode.new("div", key: "child1")
      child2 = Elements::VDOM::VNode.new("div", key: "child2")
      parent.children << child1
      parent.children << child2

      with_event_log do |log|
        document = Elements::VDOM::API::ServerDOM::Document.new
        container_element = document.create_element("div")
        parent.append_to(container_element)
        element = container_element.child_nodes[0]

        expected_events = [
          { args: [ Elements::VDOM::VNode::Events::CREATE, element.child_nodes[0] ], self: child1 },
          { args: [ Elements::VDOM::VNode::Events::CREATE, element.child_nodes[1] ], self: child2 },
          { args: [ Elements::VDOM::VNode::Events::CREATE, element ],                self: parent },
          { args: [ Elements::VDOM::VNode::Events::INSERT, element.child_nodes[0] ], self: child1 },
          { args: [ Elements::VDOM::VNode::Events::INSERT, element.child_nodes[1] ], self: child2 },
          { args: [ Elements::VDOM::VNode::Events::INSERT, element ],                self: parent }
        ]

        log.must_equal(expected_events, "wrong event log")
      end
    end
  end

  describe "patch" do
    describe "classes" do
      it "adds classes on create" do
        n = Elements::VDOM::VNode.new("div").class("class1 class2")
        el = n.to_element()
        el.get_attribute("class").must_equal("class1 class2", "wrong class")
      end

      it "adds classes on update" do
      end

      it "removes classes on update" do
      end

      it "empties class attribute if no class" do
      end
    end

    describe "events" do
      it "adds events on create" do
        # XXX left off here
        # XXX add event handling to server dom with api methods
      end

      it "adds events on update" do
      end

      it "removes events on update" do
      end

      it "clears events on destroy" do
      end
    end

    describe "children" do
      describe "with keys" do
        # Creates a new span element with n as the inner html of the element. If n is
        # a number then create a key for the span equal to the number. If n is a
        # string then don't create a key.
        def span_num(n)
          if n.is_a?(String)
            Elements::VDOM::VNode.new("span").child(Elements::VDOM::VText.new(n))
          else
            Elements::VDOM::VNode.new("span", key: n).child(Elements::VDOM::VText.new(n.to_s))
          end
        end

        def map_span(children)
          children.map { |n| span_num(n) }
        end

        def assert_children_updated(before, after)
          vnode1 = Elements::VDOM::VNode.new("span").children(map_span(before))
          el = vnode1.append_to(@container)
          vnode2 = Elements::VDOM::VNode.new("span").children(map_span(after))
          el = vnode2.patch(el)
          actual = el.child_nodes.map { |n| n.inner_html }
          expected = after.map(&:to_s)
          assert_equal expected, actual, "children not updated correctly"
        end

        describe "addition of elements" do
          it "appends elements" do
            assert_children_updated([1], [1,2,3])
          end

          it "prepends elements" do
            assert_children_updated([4,5], [1,2,3,4,5])
          end

          it "adds elements in the middle" do
            assert_children_updated([1,2,4,5], [1,2,3,4,5])
          end

          it "adds elements at begin and end" do
            assert_children_updated([2,3,4], [1,2,3,4,5])
          end

          it "adds children to parent with no children" do
            assert_children_updated([], [1,2,3])
          end
        end

        describe "removal of elements" do
          it "removes all children from parent" do
            assert_children_updated([1,2,3], [])
          end

          it "removes elements from the beginning" do
            assert_children_updated([1,2,3,4,5], [3,4,5])
          end

          it "removes elements from the end" do
            assert_children_updated([1,2,3,4,5], [1,2,3])
          end

          it "removes elements from the middle" do
            assert_children_updated([1,2,3,4,5], [1,2,4,5])
          end
        end

        describe "element reordering" do
          it "moves element forward" do
            assert_children_updated([1,2,3,4], [2,3,1,4])
          end

          it "moves element to end" do
            assert_children_updated([1,2,3], [2,3,1])
          end

          it "moves element backwards" do
            assert_children_updated([1,2,3,4,5], [1,4,2,3])
          end

          it "swaps first and last" do
            assert_children_updated([1,2,3,4], [4,2,3,1])
          end
        end

        describe "combos" do
          it "move to left and replace" do
            assert_children_updated([1,2,3,4,5], [4,1,2,3,6])
          end

          it "moves to left and leaves hole" do
            assert_children_updated([1,4,5], [4,6])
          end

          it "handles moved and set to undefined element at end" do
            assert_children_updated([2,4,5], [4,5,3])
          end

          it "moves a key in non-keyed nodes with a size up" do
            assert_children_updated([1, 'a', 'b', 'c'], ['d', 'a', 'b', 'c', 1, 'e'])
          end

          it "reverses elements" do
            assert_children_updated([1,2,3,4,5,6,7,8], [8,7,6,5,4,3,2,1])
          end

          it "random" do
            assert_children_updated([0,1,2,3,4,5], [4,3,2,1,5,0])
          end
        end
      end

      describe "without keys" do
        it "appends elements" do
          vnode1 = vnode("div").children([
            vnode("span").child("Hello")
          ])

          vnode2 = vnode("div").children([
            vnode("span").child("Hello"),
            vnode("span").child("World")
          ])

          el = vnode1.append_to(@container)
          assert_equal "<div><span>Hello</span></div>", el.outer_html

          el = vnode2.patch(el)
          assert_equal "<div><span>Hello</span><span>World</span></div>", el.outer_html
        end

        it "handles unmoved text nodes" do
          vnode1 = vnode("div").children([
            "Text",
            vnode("span").child("Span")
          ])

          vnode2 = vnode("div").children([
            "Text",
            vnode("span").child("Span")
          ])

          el = vnode1.append_to(@container)
          assert_equal "<div>Text<span>Span</span></div>", el.outer_html

          el = vnode2.patch(el)
          assert_equal "<div>Text<span>Span</span></div>", el.outer_html
        end

        it "handles changing text children" do
          vnode1 = vnode("div").children([
            "Text",
            vnode("span").child("Span")
          ])

          vnode2 = vnode("div").children([
            "Text2",
            vnode("span").child("Span")
          ])

          el = vnode1.append_to(@container)
          assert_equal "<div>Text<span>Span</span></div>", el.outer_html

          el = vnode2.patch(el)
          assert_equal "<div>Text2<span>Span</span></div>", el.outer_html
        end

        it "prepends element" do
          vnode1 = vnode("div").children([
            vnode("span").child("World")
          ])

          vnode2 = vnode("div").children([
            vnode("span").child("Hello"),
            vnode("span").child("World")
          ])

          el = vnode1.append_to(@container)
          assert_equal "<div><span>World</span></div>", el.outer_html

          el = vnode2.patch(el)
          assert_equal "<div><span>Hello</span><span>World</span></div>", el.outer_html
        end

        it "prepends element of different tag type" do
          vnode1 = vnode("div").children([
            vnode("span").child("World")
          ])

          vnode2 = vnode("div").children([
            vnode("div").child("Hello"),
            vnode("span").child("World")
          ])

          el = vnode1.append_to(@container)
          assert_equal "<div><span>World</span></div>", el.outer_html

          el = vnode2.patch(el)
          assert_equal "<div><div>Hello</div><span>World</span></div>", el.outer_html
        end

        it "removes elements" do
          vnode1 = vnode("div").children([
            vnode("span").child("One"),
            vnode("span").child("Two"),
            vnode("span").child("Three")
          ])

          vnode2 = vnode("div").children([
            vnode("span").child("One"),
            vnode("span").child("Three")
          ])

          el = vnode1.append_to(@container)
          assert_equal "<div><span>One</span><span>Two</span><span>Three</span></div>", el.outer_html

          el = vnode2.patch(el)
          assert_equal "<div><span>One</span><span>Three</span></div>", el.outer_html
        end

        it "removes a single text node" do
          vnode1 = vnode("div").child("One")
          vnode2 = vnode("div")

          el = vnode1.append_to(@container)
          assert_equal "<div>One</div>", el.outer_html

          el = vnode2.patch(el)
          assert_equal "<div></div>", el.outer_html
        end

        it "removes a single text node when children updated" do
          vnode1 = vnode("div").child("One")

          vnode2 = vnode("div").children([
            vnode("div").child("Two"),
            vnode("span").child("Three")
          ])

          el = vnode1.append_to(@container)
          assert_equal "<div>One</div>", el.outer_html

          el = vnode2.patch(el)
          assert_equal "<div><div>Two</div><span>Three</span></div>", el.outer_html
        end

        it "removes a text node among other elements" do
          vnode1 = vnode("div").children([
            "One",
            vnode("span").child("Two")
          ])

          vnode2 = vnode("div").children([
            vnode("div").child("Three"),
          ])

          el = vnode1.append_to(@container)
          assert_equal "<div>One<span>Two</span></div>", el.outer_html

          el = vnode2.patch(el)
          assert_equal "<div><div>Three</div></div>", el.outer_html
        end

        it "reorders elements" do
          vnode1 = vnode("div").children([
            vnode("span").child("One"),
            vnode("div").child("Two"),
            vnode("b").child("Three"),
          ])

          vnode2 = vnode("div").children([
            vnode("b").child("Three"),
            vnode("span").child("One"),
            vnode("div").child("Two"),
          ])

          el = vnode1.append_to(@container)
          assert_equal "<div><span>One</span><div>Two</div><b>Three</b></div>", el.outer_html

          el = vnode2.patch(el)
          assert_equal "<div><b>Three</b><span>One</span><div>Two</div></div>", el.outer_html
        end
      end
    end
  end
end
