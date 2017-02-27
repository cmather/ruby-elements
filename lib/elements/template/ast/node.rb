require "elements/assertions"
require "elements/template/location"

module Elements
  module Template
    module AST
      class Node
        include Assertions

        attr_reader :filepath
        attr_reader :location
        attr_accessor :prev_sibling
        attr_accessor :next_sibling
        attr_accessor :parent

        def initialize(options = {})
          @filepath = options[:filepath]
          @source = options[:source]
          @location = options[:location] || Location.new
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
      end
    end
  end
end
