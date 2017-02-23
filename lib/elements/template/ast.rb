require "elements/assertions"
require "elements/template/location"

module Elements
  module Template
    module AST
      class Node
        include Assertions

        attr_reader :location
        attr_accessor :prev_sibling
        attr_accessor :next_sibling
        attr_accessor :parent

        def initialize(location = Location.new)
          @location = location
          @prev_sibling = nil
          @next_sibling = nil
          @parent = nil
        end

        def <<(node)
          raise NotImplementedError
        end

        # Preorder traversal of the abstract syntax tree.
        def preorder(&block)
          return to_enum(:preorder) unless block_given?
          yield self if block_given?
        end

        alias_method :traverse, :preorder

        def compile
          raise NotImplementedError
        end
      end

      class NodeCollection
        include Enumerable
        include Assertions

        attr_reader :parent
        attr_reader :children

        def initialize(parent = nil)
          @parent = parent
          @children = []
        end

        def size
          @children.size
        end

        def [](index)
          @children[index]
        end

        def empty?
          @children.empty?
        end

        def <<(node)
          assert_type Node, node

          # set the parent pointer of the node to this collection's parent.
          node.parent = @parent

          # if we have a previous item in this collection then set the prev/next
          # sibling pointers.
          if @children.last
            @children.last.next_sibling = node
            node.prev_sibling = @children.last
          end

          # finally, add the node to our array of children and return the node.
          @children << node
        end

        def last
          @children.last
        end

        def each(&block)
          return to_enum(:each) unless block_given?
          @children.each(&block)
        end

        def preorder(&block)
          return to_enum(:preorder) unless block_given?
          @children.each { |node| node.preorder(&block) }
        end
      end

      class Document < Node
        include Enumerable

        attr_reader :children

        def initialize(location = Location.new)
          super(location)
          @children = NodeCollection.new(self)
        end

        def <<(node)
          @location.finish = node.location.finish.dup
          @children << node
        end

        def each(&block)
          return to_enum(:each) unless block_given?
          @children.each(&block)
        end

        def preorder(&block)
          return to_enum(:preorder) unless block_given?
          yield self
          @children.preorder(&block)
        end

        def to_s
          @children.map(&:to_s).join
        end

        def compile
          @children.map(&:compile).join
        end
      end

      class Value < Node
        attr_reader :value

        def initialize(value, location = Location.new)
          super(location)
          @value = value
        end

        def to_s
          max_size = 50
          value = @value.to_s
          if value.size > max_size then "#{value[0..max_size]}..." else value; end
        end

        def preorder(&block)
          return to_enum(:preorder) unless block_given?
          yield self
        end
      end

      class Any < Value
      end

      class Text < Value
      end

      class Comment < Value
      end

      class AttributeName < Value
      end

      class AttributeValue < Value
      end

      class Attribute < Node
        attr_reader :name, :value

        def initialize(name_node, value_node = nil, boolean = false, location = Location.new)
          assert_type AttributeName, name_node
          assert_type_or_nil AttributeValue, value_node
          super(location)
          @name = name_node
          @value = value_node
          @boolean = boolean
        end

        def boolean?
          @boolean == true
        end

        def to_s
          if boolean? then name else "#{name}=\"#{value}\""; end
        end

        def preorder(&block)
          return to_enum(:preorder) unless block_given?
          yield self
          @name.preorder(&block)
          @value.preorder(&block)
        end

        def compile
          if boolean?
            "#{@name.compile} => #{@value.compile}"
          else
            "#{@name.compile} => true"
          end
        end
      end

      class AttributeCollection < NodeCollection
        def initialize(parent = nil)
          super(parent)
          @attrs = {}
        end

        def <<(node)
          assert_type Attribute, node
          super(node)
          @attrs[node.name.value.to_s] = node.value.value
        end

        def [](key)
          @attrs[key]
        end

        def has_key?(key)
          @attrs.has_key?(key)
        end

        def to_s
          children.map(&:to_s).join(" ")
        end

        def preorder(&block)
          return to_enum(:preorder) unless block_given?
          yield self
          @children.each { |attr| attr.preorder(&block) }
        end
      end

      class Tag < Node
        include Enumerable

        attr_reader :children
        attr_reader :attributes
        attr_reader :name

        def initialize(name, location = Location.new)
          super(location)
          @name = name
          @children = NodeCollection.new(self)
          @attributes = AttributeCollection.new(self)
        end

        def <<(node)
          @children << node
        end

        def to_s
          attr_values = if attributes.empty? then "" else " #{attributes}"; end
          has_children_indicator = if children.empty? then "" else "..."; end
          "<#{name}#{attr_values}>#{has_children_indicator}</#{name}>"
        end

        def each(&block)
          return to_enum(:each) unless block_given?
          @children.each(&block)
        end

        def preorder(&block)
          return to_enum(:preorder) unless block_given?
          yield self
          @attributes.preorder(&block)
          @children.preorder(&block)
        end
      end

      class Template < Tag
        def initialize(inline = false, location = Location.new)
          super("template", location)
          @inline = inline
        end

        def inline?
          !!@inline
        end
      end

      class Element < Tag
        attr_reader :namespace

        def initialize(name, namespace = nil, location = Location.new)
          super(name, location)
          @namespace = namespace
        end

        def compile
          tagname = @namespace ? "#{@namespace}:#{@name}" : @name
          compiled = []
          compiled << "VElement.new(\"#{tagname}\", #{@attributes.compile}, ["
          compiled << @children.map(&:compile).join(", ")
          compile << "])"
          compiled.join
        end
      end

      class View < Tag
      end
    end
  end
end
