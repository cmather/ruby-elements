require "elements/template/ast/tag"

module Elements
  module Template
    module AST
      class Template < Tag
        def initialize(options = {})
          super("template", options)
          @inline = !!options[:inline]
        end

        def inline?
          @inline
        end
      end
    end
  end
end
