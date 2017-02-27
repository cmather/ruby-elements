require "elements/template/ast/value"

module Elements
  module Template
    module AST
      class AttributeName < Value
        def to_s
          @value.to_s
        end
      end
    end
  end
end
