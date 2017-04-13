module Elements
  module VDOM
    module Patch
      module Classes
        def patch_classes(element)
          return unless self.instance_of?(VNode)

          existing_class_attr = api.get_attribute(element, "class")

          if classes.size > 0
            api.set_attribute(element, "class", classes.to_a.join(" "))
          elsif existing_class_attr
            api.remove_attribute(element, "class")
          end
        end
      end
    end
  end
end
