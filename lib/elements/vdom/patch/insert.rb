module Elements
  module VDOM
    module Patch
      module Insert
        def patch_insert(parent_element, new_element, next_element = nil)
          api.insert_before(parent_element, new_element, next_element)
        end
      end
    end
  end
end
