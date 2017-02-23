require "elements/vdom/base"

module Elements
  module VDOM
    class VText < Base
      def initialize(value)
        @value = value
      end
    end
  end
end
