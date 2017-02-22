require "elements/ast/tag"
require "elements/location"
require "elements/assertions"

module Elements
  module AST
    class Template < Tag
      def initialize(location = Location.new)
        super("template", location)
      end

      def compile
        # XXX compile into what? a Template object? on what namespace? Perhaps
        # on no namespace by default it's just inline. But maybe it's a class
        # that inherits from Template or something like that.
        #
        # XXX also, need to design 
        #
        # module MyNamespace
        #   class MyTemplate < Elements::Template
        #     def call
        #       # returns an array of vnode's?
        #     end
        #   end
        # end
      end
    end
  end
end
