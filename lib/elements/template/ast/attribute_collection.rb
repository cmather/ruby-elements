require "elements/template/ast/node_collection"

module Elements
  module Template
    module AST
      class AttributeCollection < NodeCollection
        def initialize(parent, options = {})
          super(parent)
          @attrs = {}
          @options = options
          if (options[:attributes] && options[:attributes].respond_to?(:each))
            options[:attributes].each { |node| add(node) }
          end
        end

        def add(node)
          assert_type Attribute, node

          super(node)

          if node.boolean?
            @attrs[node.name.value.to_s] = true
          else
            @attrs[node.name.value.to_s] = node.value.value
          end
        end

        alias_method :<<, :add

        def [](key)
          @attrs[key]
        end

        def has_key?(key)
          @attrs.has_key?(key)
        end

        def to_s
          @children.map(&:to_s).join(" ")
        end
      end
    end
  end
end
