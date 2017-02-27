require "elements/template/ast/tag"

module Elements
  module Template
    module AST
      class Element < Tag
        attr_reader :namespace

        def initialize(name, options = {})
          super(name, options)
          @namespace = options[:namespace]
        end
      end
    end
  end
end
