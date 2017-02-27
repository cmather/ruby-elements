require "elements/template/ast/value"

module Elements
  module Template
    module AST
      class AttributeValue < Value
        def to_s
          "\"#{value}\""
        end
      end
    end
  end
end
