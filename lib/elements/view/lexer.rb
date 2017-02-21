require "strscan"
require "elements/view/location"

module Elements
  module View
    class Token
      attr_reader :type, :value, :location
      def initialize(type, value, location)
        @type, @value, @location = type, value, location
      end

      def to_s
        "'#{@value.to_s}'"
      end
    end

    class Lexer
      class LexerError < StandardError; end

      module Matchers
        # spaces and newlines
        SPACE                                = /\s/
        TAB                                  = /\t/
        WHITESPACE                           = /#{SPACE}|#{TAB}/
        NEWLINE                              = /\r?\n/
        SEA_WS                               = /#{WHITESPACE}|#{NEWLINE}/

        # templates
        TEMPLATE_OPEN                        = /<template/
        TEMPLATE_CLOSE                       = /<\/template>/

        # tag symbols
        OPEN_CARET_FORWARD_SLASH             = /<\//
        # FIXME open caret should exclude <template so we don't end up with a
        # nested template tag. or actually nested templates are a good thing so
        # we'll come back to this idea.
        OPEN_CARET                           = /</
        CLOSE_CARET                          = />/
        FORWARD_SLASH_CLOSE_CARET            = /\/>/
        EQUALS                               = /=/

        # tag and view names
        TAG_NAME_PART                        = /[a-z][a-z0-9]*/
        TAG_NAME                             = /#{TAG_NAME_PART}(?:-#{TAG_NAME_PART})*/
        TAG_NAMESPACE                        = /([a-z]*):/
        VIEW_NAME_PART                       = /[A-Z]\w+/
        VIEW_NAME                            = /#{VIEW_NAME_PART}(?:::#{VIEW_NAME_PART})*/

        # attributes
        ATTRIBUTE_NAME                       = TAG_NAME
        ATTRIBUTE_VALUE_SINGLE_QUOTED_STRING = /'([^']+)'/
        ATTRIBUTE_VALUE_DOUBLE_QUOTED_STRING = /"([^"]+)"/
        ATTRIBUTE_VALUE_CHAR                 = /-|_|\.|\/|\+|,|\?|=|:|;|#|[0-9a-zA-Z]/
        ATTRIBUTE_VALUE_CHARS                = /#{ATTRIBUTE_VALUE_CHAR}+/
        ATTRIBUTE_VALUE_HEXCHARS             = /#[0-9a-fA-F]+/
        ATTRIBUTE_VALUE_PCTCHARS             = /[0-9]+%/

        # any, comment and text
        ANY                                  = /(?:(?!#{TEMPLATE_OPEN}).)+/m
        COMMENT                              = /<!--\s*(.*?)\s*-->/m
        TEXT                                 = /(?:(?!#{OPEN_CARET}).)+/m
      end

      attr_reader :lookahead
      attr_reader :source
      attr_accessor :state

      def initialize(io, opts = {})
        @source = if io.respond_to?(:read) then io.read else io; end
        @scanner = StringScanner.new(@source)
        @location_index = LocationIndex.new
        @lookahead = nil
        @state = opts[:state] || :default
      end

      def state?(value)
        @state == value
      end

      def scan
        if @scanner.eos?
          @lookahead = Token.new(:EOF, nil, nil) if @scanner.eos?
          return @lookahead
        end

        case @state
        when :default         then scan_in_default_state
        when :template        then scan_in_template_state
        when :open_tag        then scan_in_open_tag_state
        when :attributes      then scan_in_attributes_state
        when :attribute_value then scan_in_attribute_value_state
        when :close_tag       then scan_in_close_tag_state
        end
      end

      def eof?
        @lookahead && @lookahead.type == :EOF
      end

      def line
        @location_index.line
      end

      def column
        @location_index.column
      end

      def index
        @location_index.index
      end

      private
      def scan_in_default_state
        case
        when matched = @scanner.scan(Matchers::ANY)
          type = :ANY

        when matched = @scanner.scan(Matchers::TEMPLATE_OPEN)
          type = :TEMPLATE_OPEN
          @state = :attributes

        else
          error
        end

        location = @location_index.advance(@scanner.matched)
        @lookahead = Token.new(type, matched, location)
      end

      def scan_in_template_state
        skip_whitespace

        case
        when @scanner.scan(Matchers::COMMENT)
          matched = @scanner[1]
          type = :COMMENT

        when matched = @scanner.scan(Matchers::TEMPLATE_CLOSE)
          type = :TEMPLATE_CLOSE
          @state = :default

        when matched = @scanner.scan(Matchers::OPEN_CARET_FORWARD_SLASH)
          type = :OPEN_CARET_FORWARD_SLASH
          @state = :close_tag

        when matched = @scanner.scan(Matchers::OPEN_CARET)
          type = :OPEN_CARET
          @state = :open_tag

        when matched = @scanner.scan(Matchers::TEXT)
          type = :TEXT

        else
          error
        end

        location = @location_index.advance(@scanner.matched)
        @lookahead = Token.new(type, matched, location)
      end

      def scan_in_open_tag_state
        # tag name, ns tag name, viewname are the only acceptable things. and
        # then we push on attributes
        skip_whitespace

        case
        when @scanner.scan(Matchers::TAG_NAMESPACE)
          matched = @scanner[1]
          type = :TAG_NAMESPACE

        when matched = @scanner.scan(Matchers::TAG_NAME)
          type = :TAG_NAME
          @state = :attributes

        when matched = @scanner.scan(Matchers::VIEW_NAME)
          type = :VIEW_NAME
          @state = :attributes

        else
          error
        end

        location = @location_index.advance(@scanner.matched)
        @lookahead = Token.new(type, matched, location)
      end

      def scan_in_attributes_state
        skip_whitespace

        case
        when matched = @scanner.scan(Matchers::ATTRIBUTE_NAME)
          type = :ATTRIBUTE_NAME

        when matched = @scanner.scan(Matchers::EQUALS)
          type = :EQUALS
          @state = :attribute_value

        when matched = @scanner.scan(Matchers::FORWARD_SLASH_CLOSE_CARET)
          type = :FORWARD_SLASH_CLOSE_CARET
          @state = :template

        when matched = @scanner.scan(Matchers::CLOSE_CARET)
          type = :CLOSE_CARET
          @state = :template

        else
          error
        end

        location = @location_index.advance(@scanner.matched)
        @lookahead = Token.new(type, matched, location)
      end

      def scan_in_attribute_value_state
        skip_whitespace

        case
        when @scanner.scan(Matchers::ATTRIBUTE_VALUE_SINGLE_QUOTED_STRING)
          matched = @scanner[1]
          type = :ATTRIBUTE_VALUE
          @state = :attributes

        when @scanner.scan(Matchers::ATTRIBUTE_VALUE_DOUBLE_QUOTED_STRING)
          matched = @scanner[1]
          type = :ATTRIBUTE_VALUE
          @state = :attributes

        when matched = @scanner.scan(Matchers::ATTRIBUTE_VALUE_HEXCHARS)
          type = :ATTRIBUTE_VALUE
          @state = :attributes

        when matched = @scanner.scan(Matchers::ATTRIBUTE_VALUE_PCTCHARS)
          type = :ATTRIBUTE_VALUE
          @state = :attributes

        when matched = @scanner.scan(Matchers::ATTRIBUTE_VALUE_CHARS)
          type = :ATTRIBUTE_VALUE
          @state = :attributes

        else
          error
        end

        location = @location_index.advance(@scanner.matched)
        @lookahead = Token.new(type, matched, location)
      end

      def scan_in_close_tag_state
        skip_whitespace

        case
        when @scanner.scan(Matchers::TAG_NAMESPACE)
          matched = @scanner[1]
          type = :TAG_NAMESPACE
        when matched = @scanner.scan(Matchers::TAG_NAME)
          type = :TAG_NAME
        when matched = @scanner.scan(Matchers::VIEW_NAME)
          type = :VIEW_NAME
        when matched = @scanner.scan(Matchers::CLOSE_CARET)
          type = :CLOSE_CARET
          @state = :template
        else
          error
        end

        location = @location_index.advance(@scanner.matched)
        @lookahead = Token.new(type, matched, location)
      end

      def skip_whitespace
        while @scanner.scan(Matchers::SEA_WS)
          @location_index.advance(@scanner.matched)
        end
      end

      def error
        raise LexerError.new("Unexpected character: '#{@scanner.peek(1)}'. Location: #{@location_index}. State: #{@state}")
      end
    end
  end
end
