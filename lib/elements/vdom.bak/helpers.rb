require "elements/vdom"

module Elements
  module VDOM
    module Helpers
      def vnode(*args)
        VNode.new(*args)
      end

      def vtext(*args)
        VText.new(*args)
      end

      def vcomment(*args)
        VComment.new(*args)
      end
    end
  end
end
