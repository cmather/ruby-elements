require "elements/view/lexer"
require "elements/view/ast"
require "elements/view/tag_helpers"

module Elements
  module View
    class Parser
      include TagHelpers

      def initialize(io, opts = {})
        @lexer = Lexer.new(io, opts)
        @lexer.scan

        # i'll keep an explicit stack vs. just a call stack because we need to
        # be able to unwind the stack for autoclosing html tags and error
        # handling. So rather than have one part of the parser be recursive
        # descent with functions and another part of the parser use an explicit
        # stack, I'll just use an explicit stack for all of it.
        @stack = []
      end

      def stack_size
        @stack.size
      end

      def parse_document
        AST::Document.new.tap do |ast_node|
          @stack.push(ast_node)
          parse_document_body until @lexer.eof?
          @stack.pop()
        end
      end

      alias_method :parse, :parse_document

      def parse_document_body
        case @lexer.lookahead.type
        when :ANY
          parse_any
        when :TEMPLATE_OPEN
          parse_template
        else
          error
        end
      end

      def parse_any
        token = match(:ANY)
        AST::Any.new(token.value, token.location).tap do |ast_node|
          @stack.last << ast_node unless @stack.empty?
        end
      end

      def parse_template
        AST::Template.new.tap do |ast_node|
          # make this template the child of whatever is on the stack which
          @stack.last << ast_node unless @stack.empty?

          # now push ourselves onto the stack
          @stack.push(ast_node)

          open_tag_token = match(:TEMPLATE_OPEN)

          # parse the template's attributes
          @stack.push(ast_node.attributes)
          parse_attributes
          @stack.pop()

          # match the close of the open template tag <template ... >
          match(:CLOSE_CARET)

          parse_template_body until @lexer.lookahead.type == :TEMPLATE_CLOSE

          # parse the </template> tag
          close_tag_token = match(:TEMPLATE_CLOSE)

          # now we've got the start and finish locations for the entire template
          # so assign those locations to the template ast node.
          ast_node.location.start = open_tag_token.location.start
          ast_node.location.finish = close_tag_token.location.finish

          # pop the template ast node off the stack
          @stack.pop()
        end
      end

      def parse_template_body
        case @lexer.lookahead.type
        when :OPEN_CARET # "<"
          parse_open_tag
        when :OPEN_CARET_FORWARD_SLASH # "</"
          parse_close_tag
        when :COMMENT
          parse_comment
        when :TEXT
          parse_text
        else
          error
        end
      end

      def parse_open_tag
        start_token = match(:OPEN_CARET)

        case @lexer.lookahead.type
        when :TAG_NAMESPACE
          namespace_token = match(:TAG_NAMESPACE)
          name_token = match(:TAG_NAME)
          type = :element
        when :TAG_NAME
          name_token = match(:TAG_NAME)
          type = :element
        when :VIEW_NAME
          name_token = match(:VIEW_NAME)
          type = :view
        else
          error
        end

        if type == :element
          namespace = namespace_token ? namespace_token.value : nil
          ast_node = AST::Element.new(name_token.value, namespace)
        elsif type == :view
          ast_node = AST::View.new(name_token.value)
        end

        # if the last node on the stack is an element let's see if we're
        # supposed to autoclose it. if so we'll pop it off the stack. otherwise
        # this new ast node will get added as a child.
        if @stack.last.is_a?(AST::Element)
          prev_tag_node = @stack.last
          if can_auto_close_tag?(prev_tag_node.name, ast_node.name)
            @stack.pop
          end
        end

        # if there's already an ast node on the stack then add this new ast node
        # as a child of the node on the stack. note: we only autoclose the last
        # tag on the stack. i don't ever allow multiple unclosed items on the
        # stack. so at worst one tag will be autoclosed and the previous one on
        # the stack will then become the parent.
        @stack.last << ast_node unless @stack.empty?

        # parse the tag's attributes
        @stack.push(ast_node.attributes)
        parse_attributes
        @stack.pop()

        # now, maybe push the tag ast node onto the stack unless it's a void tag
        # or self closing. either way, grab the finish token so we can get a
        # final location object for the tag's ast node.
        case @lexer.lookahead.type
        when :CLOSE_CARET # ">"
          finish_token = match(:CLOSE_CARET)
          @stack.push(ast_node) unless type == :element && void_tag?(ast_node.name)
        when :FORWARD_SLASH_CLOSE_CARET # "/>"
          finish_token = match(:FORWARD_SLASH_CLOSE_CARET)
        else
          error
        end

        # for now set the finish location to be the end of the open tag. if
        # there ends up being a corresponding closing tag down the road then
        # we'll update the finish location to be the end of the closing tag.
        ast_node.location.start = start_token.location.start
        ast_node.location.finish = finish_token.location.finish

        # and finally, return the new ast node to the caller
        ast_node
      end

      def parse_close_tag
        start_token = match(:OPEN_CARET_FORWARD_SLASH) # "</"

        case @lexer.lookahead.type
        when :TAG_NAMESPACE
          namespace_token = match(:TAG_NAMESPACE)
          name_token = match(:TAG_NAME)
          type = :element
        when :TAG_NAME
          name_token = match(:TAG_NAME)
          type = :element
        when :VIEW_NAME
          name_token = match(:VIEW_NAME)
          type = :view
        else
          error
        end

        finish_token = match(:CLOSE_CARET)

        name = name_token.value
        namespace = namespace_token ? namespace_token.value : nil
        namespace_str = if namespace then namespace + ':' else ''; end
        close_tag = "</#{namespace_str}#{name}>"

        # if the user is trying to close a void tag we're not going to find it
        # on the stack. we could throw a parser error but i think this is a
        # silly part of the html spec and will be frustrating for users to have
        # to remember which tags they have to close vs which ones are
        # autoclosing. so let's just do the right thing here and forget we ever
        # saw this, shall we?
        return nil if void_tag?(name_token.value)

        # if the last tag on the stack is an AST::Tag and it is not the tag
        # we're currently trying to close, see if we can autoclose it. if not
        # raise an error that we found an unclosed tag on the stack.
        if @stack.last.is_a?(AST::Tag) && @stack.last.name != name_token.value
          if can_auto_close_tag?(@stack.last.name)
            @stack.pop
          else
            error("While trying to parse #{close_tag} I found this tag was left open: #{@stack.last}. Try closing it first.", @stack.last)
          end
        end

        # now check that the last tag is the one we're trying to close. if it's
        # not then raise an error that says we can't find an open tag for this
        # close tag.
        if @stack.last.is_a?(AST::Element) && @stack.last.namespace == namespace && @stack.last.name == name
          ast_node = @stack.pop
        elsif @stack.last.is_a?(AST::View) && @stack.last.name == name
          ast_node = @stack.pop
        else
          location = Location.from_tokens(start_token, finish_token)
          error("Unable to find open tag for #{close_tag}", location)
        end

        # fix up the open tag ast node to have a new finish location based on
        # the finish location of the close tag caret.
        ast_node.location.finish = finish_token.location.finish.dup

        # and finally return the original ast node
        ast_node
      end

      def parse_comment
        token = match(:COMMENT)

        AST::Comment.new(token.value, token.location).tap do |ast_node|
          @stack.last << ast_node unless @stack.empty?
        end
      end

      def parse_text
        token = match(:TEXT)

        AST::Text.new(token.value, token.location).tap do |ast_node|
          @stack.last << ast_node unless @stack.empty?
        end
      end

      def parse_attributes
        [].tap do |attrs|
          while @lexer.lookahead.type == :ATTRIBUTE_NAME
            attrs << parse_attribute()
          end
        end
      end

      def parse_attribute
        name_token = match(:ATTRIBUTE_NAME)

        if @lexer.lookahead.type == :EQUALS
          match(:EQUALS)
          value_token = match(:ATTRIBUTE_VALUE)
          location = Location.from_tokens(name_token, value_token)
          value = value_token.value
        else
          location = Location.from_tokens(name_token, name_token)
          value = true
        end

        AST::Attribute.new(name_token.value, value, location).tap do |ast_node|
          @stack.last << ast_node unless @stack.empty?
        end
      end

      private
      def match(type, &block)
        token = @lexer.lookahead

        if token.type == type
          yield token if block_given?
          @lexer.scan
          return token
        else
          error
        end
      end

      def error(msg = nil, location = nil)
        msg = msg || "Unexpected token: #{@lexer.lookahead} at #{@lexer.lookahead.location}."
        raise SyntaxError.new(msg, location, @lexer.source)
      end

      class << self
        def parse(io, opts = {})
          new(io, opts).parse
        end
      end
    end

    class SyntaxError < StandardError
      def initialize(msg, location, source)
        super(msg)
        @location = location
        @source = source
      end
    end
  end
end
