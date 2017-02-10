module Elements
  module View
    class Position
      attr_reader :index, :line, :column
      def initialize(index, line, column)
        @index, @line, @column = index, line, column
      end

      def to_s
        "#<Position index=#{@index} line=#{@line} column=#{@column}>"
      end
    end

    class Location
      attr_reader :start, :finish
      def initialize(start, finish)
        @start, @finish = start, finish
      end

      def to_s
        "#<Location start=#{@start} finish=#{@finish}>"
      end
    end

    # Tracks the current line and column number of the lexer. The lines
    # are 1 indexed and the columns are 0 indexed. So if you're on the first
    # character of the first line the line is 1 and the column is 0. This is
    # to match behavior in editors and source maps.
    class LocationIndex
      module Matchers
        NEWLINE = /\r?\n/
      end

      attr_reader :line, :column, :index
      def initialize
        @line = 1
        @column = 0
        @index = 0
      end

      def to_s
        "#<LocationIndex line=#{@line} column=#{@column} index=#{@index}>"
      end

      # Advances the line and column and yields the start and finish line
      # and columns for the matched input. The start_column will be
      # inclusive of the first character in the match. The finish_column
      # will be exclusive of the last column. In other words, it's the
      # position of the last character + 1. For example, let's say the
      # matched string is "123" and the current column is 0. The
      # start_column will be 0 and the finish_column will be 3 (one past the
      # zero indexed last position of the matched string). One exception to this
      # rule is if the matched string ends in a newline. In this case, the
      # finishing column will be 0 and the finish line will be +1.
      def advance(matched, &block)
        start_index = @index
        start_line = @line
        start_column = @column

        # ok this is a correct way to get the line count
        line_count = matched.count("\r?\n")
        @line += line_count

        if line_count > 0
          # if the there is more than one line in the match then we need to
          # either advance the column to the end of the last line, or to 0 in
          # the case the last character is a newline. for example, if the
          # matched string is "hello\n" then the next advance will start at line
          # 2 and character 0. but if the matched string is "hello\nworld" then
          # the next advance will start at line 2 character 6 (the size of 'world').
          if matched[-1] == "\n"
            @column = 0
          else
            @column = matched.lines.last.size
          end
        else
          # otherwise increment the column by the matched size if we're still on
          # the same line.
          @column += matched.size
        end

        # the index is an absolute index of character positions in the source
        # text. so advance it by the size of the matched text.
        @index += matched.size

        location = Location.new(
          Position.new(start_index, start_line, start_column), # start
          Position.new(@index, @line, @column) # finish
        )

        yield location if block_given?
        return location
      end
    end
  end
end
