require "strscan"
require "elements/template/location"

module Elements
  module Template
    module States
      DEFAULT             = :default
      TEMPLATE            = :template
      TAG_NAME            = :tag_name
      TAG_ATTRIBUTES      = :tag_attributes
      TAG_ATTRIBUTE_VALUE = :tag_attribute_value
      TAG_CLOSE           = :tag_close
    end

    class Token
      attr_reader :type, :value, :location
      def initialize(type, value, location)
        @type, @value, @location = type, value, location
      end

      def to_s
        "'#{@value.to_s}'"
      end
    end

    class Rule
      attr_reader :matcher
      attr_reader :action
      def initialize(matcher, &action)
        @matcher = matcher
        @action = action
      end
    end

    class RuleSet
      def initialize
        @rules = {}
      end

      def [](state)
        @rules[state] ||= []
      end
    end

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
      OPEN_CARET_FORWARD_SLASH             = /(?:(?!#{TEMPLATE_CLOSE})<\/)/
      OPEN_CARET                           = /(?:(?!#{TEMPLATE_OPEN})<)/
      CLOSE_CARET                          = />/
      FORWARD_SLASH_CLOSE_CARET            = /\/>/
      EQUALS                               = /=/

      # tag and view names
      TAG_NAME_PART                        = /[a-z][a-z0-9]*/
      TAG_NAME                             = /#{TAG_NAME_PART}(?:-#{TAG_NAME_PART})*/
      TAG_NAMESPACE                        = /([a-z]*):/
      ELEMENT_NAME                         = TAG_NAME
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

    class Lexer
      class << self
        def rules
          @rules ||= RuleSet.new
        end

        def state(name, &block)
          begin
            saved_state = @current_state
            @current_state = name
            yield
          ensure
            @current_state = saved_state
          end
        end

        def current_state
          @current_state || States::DEFAULT
        end

        def match(matcher, state = current_state, &action)
          rules[state] << Rule.new(matcher, &action)
        end
      end

      state States::DEFAULT do
        match(Matchers::ANY)                                  { token(:ANY, @scanner.matched) }
        match(Matchers::TEMPLATE_OPEN)                        { push_state(States::TEMPLATE); push_state(States::TAG_ATTRIBUTES); token(:TEMPLATE_OPEN, @scanner.matched) }
      end

      state States::TEMPLATE do
        match(Matchers::COMMENT)                              { token(:COMMENT, @scanner[1]) }
        match(Matchers::TEMPLATE_OPEN)                        { push_state(States::TEMPLATE); token(:TEMPLATE_OPEN, @scanner.matched) }
        match(Matchers::TEMPLATE_CLOSE)                       { pop_state; token(:TEMPLATE_CLOSE, @scanner.matched) }
        match(Matchers::OPEN_CARET_FORWARD_SLASH)             { push_state(States::TAG_CLOSE); token(:OPEN_CARET_FORWARD_SLASH, @scanner.matched) }
        match(Matchers::OPEN_CARET)                           { push_state(States::TAG_NAME); token(:OPEN_CARET, @scanner.matched) }
        match(Matchers::TEXT)                                 { token(:TEXT, @scanner.matched) }
      end

      state States::TAG_NAME do
        match(Matchers::TAG_NAMESPACE)                        { token(:TAG_NAMESPACE, @scanner[1]) }
        match(Matchers::ELEMENT_NAME)                         { pop_state; push_state(States::TAG_ATTRIBUTES); token(:ELEMENT_NAME, @scanner.matched) }
        match(Matchers::VIEW_NAME)                            { pop_state; push_state(States::TAG_ATTRIBUTES); token(:VIEW_NAME, @scanner.matched) }
      end

      state States::TAG_ATTRIBUTES do
        match(Matchers::ATTRIBUTE_NAME)                       { token(:ATTRIBUTE_NAME, @scanner.matched) }
        match(Matchers::EQUALS)                               { push_state(States::TAG_ATTRIBUTE_VALUE); token(:EQUALS, @scanner.matched) }
        match(Matchers::FORWARD_SLASH_CLOSE_CARET)            { pop_state; token(:FORWARD_SLASH_CLOSE_CARET, @scanner.matched) }
        match(Matchers::CLOSE_CARET)                          { pop_state; token(:CLOSE_CARET, @scanner.matched) }
      end

      state States::TAG_ATTRIBUTE_VALUE do
        match(Matchers::ATTRIBUTE_VALUE_SINGLE_QUOTED_STRING) { pop_state; token(:ATTRIBUTE_VALUE, @scanner[1]) }
        match(Matchers::ATTRIBUTE_VALUE_DOUBLE_QUOTED_STRING) { pop_state; token(:ATTRIBUTE_VALUE, @scanner[1]) }
        match(Matchers::ATTRIBUTE_VALUE_HEXCHARS)             { pop_state; token(:ATTRIBUTE_VALUE, @scanner.matched) }
        match(Matchers::ATTRIBUTE_VALUE_PCTCHARS)             { pop_state; token(:ATTRIBUTE_VALUE, @scanner.matched) }
        match(Matchers::ATTRIBUTE_VALUE_CHARS)                { pop_state; token(:ATTRIBUTE_VALUE, @scanner.matched) }
      end

      state States::TAG_CLOSE do
        match(Matchers::TAG_NAMESPACE)                        { token(:TAG_NAMESPACE, @scanner[1]) }
        match(Matchers::ELEMENT_NAME)                         { token(:ELEMENT_NAME, @scanner.matched) }
        match(Matchers::VIEW_NAME)                            { token(:VIEW_NAME, @scanner.matched) }
        match(Matchers::CLOSE_CARET)                          { pop_state; token(:CLOSE_CARET, @scanner.matched) }
      end

      attr_reader :lookahead

      def initialize(io, **options)
        @options = options.dup
        @source = if io.respond_to?(:read) then io.read else io; end
        @scanner = StringScanner.new(@source)
        @location_index = LocationIndex.new
        @lookahead = nil
        @states = []
        @states << @options[:state] unless @options[:state].nil?
      end

      def state
        @states.last || States::DEFAULT
      end

      def push_state(state)
        @states.push(state)
      end

      def pop_state
        @states.pop
      end

      def scan
        # if we're at the end of the input stream then return the end of file
        # (EOF) token.
        if @scanner.eos?
          return Token.new(:EOF, nil, nil)
        end

        # if we encounter whitespace just return that to the parser so it can
        # decide what to do.
        if @scanner.scan(Matchers::SEA_WS)
          return token(:SEA_WS, @scanner.matched)
        end

        # find the first rule that matches given our state and call the action
        # callback defined for that match.
        for rule in rules[state] do
          if @scanner.scan(rule.matcher)
            return instance_eval(&rule.action)
          end
        end

        # if we get down here it means there were no matchers. so what we'll do
        # is create a generic token for whatever character we encountered. and
        # we'll let the parser decide what kind of error to raise, if any.
        type = value = @scanner.getch
        token(type, value)
      end

      private
      def token(type, value = nil)
        location = @location_index.advance(@scanner.matched)
        @lookahead = Token.new(type, value, location)
      end

      def rules
        self.class.rules
      end
    end
  end
end
