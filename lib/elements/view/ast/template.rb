require "elements/view/ast/tag"
require "elements/view/location"
require "elements/view/assertions"

module Elements
  module View
    module AST
      class Template < Tag
        def initialize(location = Location.new)
          super("template", location)
        end
      end
    end
  end
end
