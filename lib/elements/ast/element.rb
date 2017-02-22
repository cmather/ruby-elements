require "elements/ast/tag"
require "elements/location"
require "elements/assertions"

module Elements
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
