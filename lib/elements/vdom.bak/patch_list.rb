module Elements
  module VDOM
    # Wraps an array of children dom nodes or vnodes. This is used in the
    # children diffing algorithm of vnode to track where we are in two lists of
    # children during patching. This class provides abstractions around
    # traversing the child list with methods like left, right, move_left and
    # move_right and allows us to access the children values at the left and
    # right indices.
    class PatchList
      include Enumerable

      attr_reader :left_idx, :right_idx

      def initialize(children)
        # do a shallow clone of the array so that if the original dom node array
        # is mutated it doesn't affect our iteration. note: we don't want to
        # copy the actual dom elements, just the array itself is sufficient to
        # maintain the element positions in the array through our iteration.
        @children = children.clone
        @left_idx = 0
        @right_idx = children.size - 1
      end

      def left
        @children[@left_idx]
      end

      def right
        @children[@right_idx]
      end

      def move_right
        @left_idx += 1
      end

      def move_left
        @right_idx -= 1
      end

      def [](idx)
        @children[idx]
      end

      def []=(idx, value)
        @children[idx] = value
      end

      def each(&block)
        to_enum(:each) unless block_given?
        @children.each(&block)
        self
      end
    end
  end
end
