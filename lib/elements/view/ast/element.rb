require "elements/view/ast/tag"
require "elements/view/location"
require "elements/view/assertions"

module Elements
  module View
    module AST
      class Element < Tag
        attr_reader :namespace

        def initialize(name, namespace = nil, location = Location.new)
          super(name, location)
          @namespace = namespace
        end
      end
    end
  end
end
