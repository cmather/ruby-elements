require "set"
require "ostruct"
require "elements/core/events"
require "elements/vdom/vbase"
require "elements/vdom/patch/insert"
require "elements/vdom/patch/remove"
require "elements/vdom/patch/classes"
require "elements/vdom/patch/events"

if RUBY_ENGINE == "opal"
require "elements/vdom/api/browser"
else
require "elements/vdom/api/server"
end

module Elements
  module VDOM
    class VNode
      include Elements::Core::Events
      include Patch::Insert
      include Patch::Remove
      include Patch::Classes
      include Patch::Events

      VNODE_KEY_ATTR = "data-vnode-key"

      module Events
        CREATE    = "create"
        INSERT    = "insert"
        REMOVE    = "remove"
        DESTROY   = "destroy"
        PREPATCH  = "prepatch"
        PATCH     = "patch"
        POSTPATCH = "postpatch"
      end

      if RUBY_ENGINE == "opal"
      @@api = API::Browser.new
      else
      @@api = API::Server.new
      end

      attr_reader :tag
      attr_reader :key
      attr_reader :classes
      attr_reader :events
      attr_reader :node_name

      on Events::CREATE, :patch_classes
      on Events::PATCH,  :patch_classes
      on Events::CREATE, :patch_events
      on Events::PATCH,  :patch_events

      def initialize(tag, attributes = {}, children = [])
        @key = key
        @tag = tag
        @node_name = @tag.upcase
        @children = []

        # add each child and perform a typecheck/coercsion on the child.
        children.each { |child| add(child) }

        @attributes = attributes

        @classes = Set.new
        class_attr = @attributes.delete(:class)
        add_class(class_attr) unless class_attr.nil?

        @events = {}
      end

      def add_class(value)
        value.to_s.split(/\s/).each do |classname|
          classname.strip!
          @classes.add(classname) unless classname.empty?
        end

        self
      end

      def event(key, handler, opts = {capture: false})
        @events[key] = {key: key, handler: handler, opts: opts.dup}
        self
      end

      def add(vnode)
        if vnode.is_a?(String)
          vnode = VText.new(vnode)
        elsif !vnode.is_a?(VNode)
          raise TypeError, "Expected VNode but got #{vnode.class.name}"
        end

        @children << vnode

        self
      end

      alias_method :<<, :add

      def insert_before(sibling_element)
        insert_queue = []
        new_element = to_dom(insert_queue)
        parent_element = api.parent_node(sibling_element)
        api.insert_before(parent_element, new_element, sibling_element)
        insert_queue.each { |inserted| inserted.vnode.trigger(Events::INSERT, inserted.element) }
        new_element
      end

      def append_to(parent_element)
        insert_queue = []
        new_element = to_dom(insert_queue)
        api.append_child(parent_element, new_element)
        insert_queue.each { |inserted| inserted.vnode.trigger(Events::INSERT, inserted.element) }
        new_element
      end

      def patch(old_element, insert_queue = [])
        if patchable?(old_element)
          new_element = old_element
          trigger(Events::PREPATCH, new_element)
          trigger(Events::PATCH, new_element)
          patch_children(new_element, insert_queue)
          trigger(Events::POSTPATCH, new_element)
        else
          new_element = to_dom(insert_queue)
          parent = api.parent_node(old_element)
          sibling = api.next_sibling(old_element)
          patch_insert(parent, new_element, sibling)
          patch_remove(old_element)
        end

        new_element
      end

      # Returns true if the given node is patchable by this +VNode+.
      def patchable?(node)
        api.node_type(node) == 1 &&
          api.node_name(node) == node_name &&
          api.get_attribute(node, VNODE_KEY_ATTR) == key
      end

      def patch_children(parent_element, insert_queue)
        dom_children = api.child_nodes(parent_element)

        if dom_children.size > 0 && children.size > 0
          dom_list = PatchChildrenList.new(dom_children)
          vnode_list = PatchChildrenList.new(children)

          while dom_list.left_idx <= dom_list.right_idx && vnode_list.left_idx <= vnode_list.right_idx do
            if dom_list.left.nil?
              dom_list.move_right
            elsif dom_list.right.nil?
              dom_list.move_left
            elsif vnode_list.left.patchable?(dom_list.left)
              element = vnode_list.left.patch(dom_list.left, insert_queue)
              vnode_list[vnode_list.left_idx] = element
              dom_list.move_right
              vnode_list.move_right
            elsif vnode_list.right.patchable?(dom_list.right)
              element = vnode_list.right.patch(dom_list.right, insert_queue)
              vnode_list[vnode_list.right_idx] = element
              dom_list.move_left
              vnode_list.move_left
            elsif vnode_list.right.patchable?(dom_list.left)
              element = vnode_list.right.patch(dom_list.left, insert_queue)
              vnode_list[vnode_list.right_idx] = element
              next_sibling = api.next_sibling(dom_list.right)
              patch_insert(parent_element, dom_list.left, next_sibling)
              dom_list.move_right
              vnode_list.move_left
            elsif vnode_list.left.patchable?(dom_list.right)
              element = vnode_list.left.patch(dom_list.right, insert_queue)
              vnode_list[vnode_list.left_idx] = element
              patch_insert(parent_element, dom_list.right, dom_list.left)
              dom_list.move_left
              vnode_list.move_right
            else
              # Map old node keys to their old position amongst their siblings
              # (idx in the children array). Only do this once, and only if
              # needed. Creates theta(n) space where n is the number of old
              # children nodes.
              dom_key_to_idx ||= begin
                {}.tap do |map|
                  dom_list.each_with_index do |child_node, idx|
                    # I put the key on data-key attribute so that the server can
                    # assign the key and it's still good when it gets to the
                    # browser. Have to check the node_type here because text nodes
                    # don't have attributes so won't have a key.
                    if api.node_type(child_node) == 1
                      key = api.get_attribute(child_node, VNODE_KEY_ATTR)
                      map[key] = idx unless key.nil?
                    end
                  end
                end
              end

              # An old element has moved
              if dom_key_to_idx.has_key?(vnode_list.left.key)
                # find out what the old index of the new vnode was
                old_idx = dom_key_to_idx[vnode_list.left.key]

                # get the element to move from the existing dom children
                dom_node_to_move = dom_list[old_idx]

                # use the leftmost vnode to patch up the dom node
                element = vnode_list.left.patch(dom_node_to_move, insert_queue)
                vnode_list[vnode_list.left_idx] = element

                # then move the dom node to its new position
                patch_insert(parent_element, dom_node_to_move, dom_list.left)

                # make the slot empty so we skip over it when we get
                # there in future iterations of the while loop.
                dom_list[old_idx] = nil

                # move the pointer along to the right in the vnode_children
                vnode_list.move_right

              # Else create the new element and insert it
              else
                element = vnode_list.left.to_dom(insert_queue)
                vnode_list[vnode_list.left_idx] = element
                patch_insert(parent_element, element, dom_list.left)
                vnode_list.move_right
              end
            end
          end

          # Insert remaining new nodes
          if dom_list.left_idx > dom_list.right_idx
            before = vnode_list[vnode_list.right_idx + 1]
            (vnode_list.left_idx..vnode_list.right_idx).each do |idx|
              vnode = vnode_list[idx]
              new_child = vnode.to_dom(insert_queue)
              patch_insert(parent_element, new_child, before)
            end

          # Else remove old nodes no longer present
          elsif vnode_list.left_idx > vnode_list.right_idx
            (dom_list.left_idx..dom_list.right_idx).each do |idx|
              old_child = dom_list[idx]
              patch_remove(old_child) unless old_child.nil?
            end
          end
        elsif children.size > 0
          children.each { |child_vnode| patch_insert(parent_element, child_vnode.to_dom(insert_queue)) }
        elsif dom_children.size > 0
          while api.first_child(parent_element)
            api.remove_child(parent_element, api.first_child(parent_element))
          end
        end

        self
      end

      def to_s
        to_html
      end

      def to_html(opts = {pretty: false})
        buffer = to_html_buffer()
        pretty = opts[:pretty]
        opts.delete(:pretty)
        return pretty ? pretty_print(buffer, opts).lstrip : buffer.join
      end

      def to_dom(insert_queue = [])
        api.create_element(@tag).tap do |element|
          children.each { |vnode| api.append_child(element, vnode.to_dom(insert_queue)) }
          api.set_attribute(element, VNODE_KEY_ATTR, key) if key
          insert_queue << OpenStruct.new(vnode: self, element: element)
          trigger(Events::CREATE, element)
        end
      end

      def to_html_buffer
        [].tap do |buffer|

          open_tag = "<#{tag}"

          if key
            key_attr = "#{VNODE_KEY_ATTR}=\"#{key}\""
            open_tag << " #{key_attr}"
          end

          if @attributes.size > 0
            attrs = @attributes.map { |k, v| "#{k.to_s}=\"#{v.to_s}\"" }.join(" ")
            open_tag << " #{attrs}"
          end

          open_tag << ">"

          buffer << open_tag
          children.each { |child| buffer << child.to_html_buffer }
          buffer << "</#{tag}>"
        end
      end

      private
      def pretty_print(value, level: 0, indent_with: "\s\s", start_indent: 0)
        if value.is_a?(Array)
          value.reduce("") do |out, v|
            out << pretty_print(v,
              level: level + 1,
              indent_with: indent_with,
              start_indent: start_indent
            )
          end
        elsif value.is_a?(String)
          if level == 0
            return "#{value}\n"
          else
            indent = (indent_with * start_indent) + (indent_with * (level - 1))
            return "#{indent}#{value}\n"
          end
        end
      end

      def api
        @@api
      end

      class << self
        def api
          @@api
        end
      end

      class PatchChildrenList
        include Enumerable

        attr_reader :left_idx, :right_idx

        def initialize(children)
          # do a shallow clone of the array so that if the original dom node array
          # is mutated it doesn't affect our iteration. note: we don't want to
          # copy the actual dom elements, just the array itself is sufficient to
          # maintain the element positions in the array through our iteration.
          @children = children.clone
          @left_idx = 0
          @right_idx = children.size - 1
        end

        def left
          @children[@left_idx]
        end

        def right
          @children[@right_idx]
        end

        def move_right
          @left_idx += 1
        end

        def move_left
          @right_idx -= 1
        end

        def [](idx)
          @children[idx]
        end

        def []=(idx, value)
          @children[idx] = value
        end

        def each(&block)
          to_enum(:each) unless block_given?
          @children.each(&block)
          self
        end
      end
    end
  end
end
