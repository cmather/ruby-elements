require "elements/vdom/base"

module Elements
  module VDOM
    class VComment < Base
      def initialize(value)
        @value = value
      end
    end
  end
end
