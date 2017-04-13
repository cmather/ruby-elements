require "elements/vdom/vbase"

module Elements
  module VDOM
    class VComment < Base
      def initialize(value)
        @value = value
      end
    end
  end
end
