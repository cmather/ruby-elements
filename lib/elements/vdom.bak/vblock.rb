require "elements/vdom/vnode"

module Elements
  module VDOM
    class VBlock < VNode
      attr_reader :view
      attr_reader :block

      def initialize(view, **options, &block)
        @options = options
        @options[:escaped] ||= true
        @view = view
        @block = block
      end

      def escaped?
        !!@options[:escaped]
      end


      def patch(element, insert_queue = [])
      end

      def to_html(**options)
      end

      def to_dom(**options)
      end

      private
      def resolve
        result = @view.instance_eval(&block)
        value = result.to_s
        if escaped? then CGI.escape(value) else value; end
      end
    end
  end
end
