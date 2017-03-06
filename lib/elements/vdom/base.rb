module Elements
  module VDOM
    class Base
      def render; raise NotImplementedError; end
      def to_html; raise NotImplementedError; end
      def to_dom; raise NotImplementedError; end
    end
  end
end
