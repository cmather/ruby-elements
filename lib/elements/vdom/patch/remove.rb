module Elements
  module VDOM
    module Patch
      module Remove
        def patch_remove(old_element)
          listener_count = count_listeners(VNode::Events::REMOVE) + 1

          parent = api.parent_node(old_element)

          # Listeners call this proc when they are ready for the dom element to
          # actually be removed. This allows a delay in the removal of the dom
          # until effects like a fade-out are applied.
          remove_callback = lambda do
            listener_count -= 1

            if listener_count == 0 && parent
              api.remove_child(parent, old_element)
              trigger(VNode::Events::DESTROY, old_element)
            end
          end

          trigger(VNode::Events::REMOVE, old_element, remove_callback)

          # Make sure the remove callback is called even if we have no listeners.
          # This is why the listener_count is +1 above. If there are other
          # listeners this is basically a noop that will decrement the listener
          # count by 1. Then it's up to the other listeners to all call their
          # respective callbacks, bring the count to 0 and remove the element.
          remove_callback.call()

          self
        end
      end
    end
  end
end
