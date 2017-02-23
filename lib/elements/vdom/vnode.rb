require "elements/vdom/base"

module Elements
  module VDOM
    class VNode < Base
      def initialize(name, attributes = {}, children = [])
        @name = name
        @attributes = attributes
        @children = children
        @namespace = if attributes.include?(:namespace) then attributes.delete(:namespace) else nil; end
      end
    end
  end
end
