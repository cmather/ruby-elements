require "elements/template/lexer"
require "elements/template/ast"
require "elements/template/tag_helpers"

module Elements
  module Template
    class Parser
      include TagHelpers

      def initialize(io, options = {})
        @options = options
        @source = if io.respond_to?(:read) then io.read else io; end
        @filepath = @options[:filepath]
        @lexer = Lexer.new(@source, options)

        # Stack of all open ast nodes. We need another stack in addition to the
        # call stack for two reasons: (1) to autoclose the prev tag if needed;
        # (2) to know which template or tag we're adding children too. We can't
        # use recursive descent because not all tags have close tags. For
        # example, the parse_template_body uses a while loop to iterate over the
        # content of a template. So to unify the approach, instead of passing a
        # parent ast node to each of the recursive descent methods I'll just use
        # this stack everywhere.
        @stack = []

        # I'll keep a separate template stack which overlaps a bit with the
        # regular stack but only contains templates. This allows me to quickly
        # check whether a new template is "inline" or nested inside another
        # template, or if it's a top level template.
        @template_stack = []
      end

      def parse
        AST::Document.new(
          with_default_options({})
        ).tap do |ast_node|
          # Push the document node onto the stack
          @stack << ast_node

          # Scan the first token
          @lexer.scan

          # Collect each document body child
          parse_document_body

          # Pop the document node off the stack
          @stack.pop
        end
      end

      alias_method :parse_document, :parse

      def parse_template
        AST::Template.new(
          with_default_options({inline: true})
        ).tap do |ast_node|
          # Push ourselves onto the template stack since we're a template
          @stack << ast_node

          # Also push the template onto the template stack.
          @template_stack << ast_node

          # Tell the lexer we're in a template now
          @lexer.push_state Lexer::States::TEMPLATE

          # Now that the lexer is in the correct state, scan the first token.
          @lexer.scan

          # Until we reach the end of the file add the template's children.
          parse_template_body

          # Since this is an anonymous template we want to set the start and
          # finish location to the first and last child of the template.
          if ast_node.children.size > 0
            ast_node.location.start = ast_node.children.first.location.start.dup
            ast_node.location.finish = ast_node.children.first.location.finish.dup
          end

          # Pop the template off the template stack.
          @template_stack.pop

          # Pop the template node off the stack.
          @stack.pop
        end
      end

      private
      def parse_document_body
        until @lexer.eof?
          case @lexer.lookahead.type
          when :ANY
            parse_any
          when :TEMPLATE_OPEN
            parse_template_tag
          else
            error "Expected :ANY or :TEMPLATE_OPEN but got #{@lexer.lookahead}."
          end
        end
      end

      def parse_any
        token = match(:ANY)
        AST::Any.new(
          token.value,
          with_default_options({location: token.location.dup})
        ).tap do |ast_node|
          @stack.last << ast_node unless @stack.empty?
        end
      end

      # Parses a template tag and adds it to the last template or tag on the
      # stack.
      def parse_template_tag
        AST::Template.new(
          with_default_options({
            # if there are already templates on the template stack that means
            # this must be an embedded (inline) template.
            inline: @template_stack.size > 0
          })
        ).tap do |ast_node|
          # make this template the child of whatever is on the stack which
          @stack.last << ast_node unless @stack.empty?

          # now push ourselves onto the stack
          @stack << ast_node

          # Also push ourselves onto the template stack.
          @template_stack << ast_node

          # Parse template tag.
          open_tag_token = match(:TEMPLATE_OPEN)

          # Parse the template's attributes. To do this we'll push the
          # template's attributes collection (AST::AttributesCollection) onto
          # the stack. This way, the parse_attributes method can look for this
          # item on the stack and add the attributes to it like this:
          # @stack.last << attribute_ast_node.
          @stack << ast_node.attributes
          parse_attributes
          @stack.pop

          # Match the close of the open template tag <template ... >
          match(:CLOSE_CARET)

          # Parse the template's body
          parse_template_body

          # Parse the </template> tag
          close_tag_token = match(:TEMPLATE_CLOSE)

          # Now we've got the start and finish locations for the entire template
          # so assign those locations to the template ast node.
          ast_node.location.start = open_tag_token.location.start
          ast_node.location.finish = close_tag_token.location.finish

          # Pop ourselves off the template stack.
          @template_stack.pop

          # Pop ourselves off the main stack.
          @stack.pop
        end
      end

      # Parses a template body adding each item to the last template or tag on
      # the stack.
      def parse_template_body
        until @lexer.lookahead.type == :TEMPLATE_CLOSE || @lexer.eof?
          case @lexer.lookahead.type
          when :TEMPLATE_OPEN
            parse_template_tag
          when :OPEN_CARET # "<"
            parse_open_tag
          when :OPEN_CARET_FORWARD_SLASH # "</"
            parse_close_tag
          when :COMMENT
            parse_comment
          when :TEXT
            parse_text
          else
            error "Unexpected token in template body: #{@lexer.lookahead.type}"
          end
        end
      end

      # Parses an open tag and adds it to the last template or tag on the stack.
      def parse_open_tag
        start_token = match(:OPEN_CARET)

        case @lexer.lookahead.type
        when :TAG_NAMESPACE
          namespace_token = match(:TAG_NAMESPACE)
          name_token = match(:ELEMENT_NAME)
          type = :element
        when :ELEMENT_NAME
          name_token = match(:ELEMENT_NAME)
          type = :element
        when :VIEW_NAME
          name_token = match(:VIEW_NAME)
          type = :view
        else
          error "Expected to see a tag name but instead got: #{@lexer.lookahead}"
        end

        if type == :element
          namespace = namespace_token ? namespace_token.value : nil
          ast_node = AST::Element.new(
            name_token.value,
            with_default_options({namespace: namespace})
          )
        elsif type == :view
          ast_node = AST::View.new(
            name_token.value,
            with_default_options({})
          )
        end

        # Autoclose the last tag if it's one of the autoclosable tags like <li>.
        # popping it off the tag stack closes the tag so that no more children
        # are added to it.
        unless @stack.empty?
          prev_tag_node = @stack.last
          @stack.pop if can_auto_close_tag?(prev_tag_node.name, ast_node.name)
        end

        # If there's already an ast node on the stack then add this new ast node
        # as a child of the node on the stack. note: we only autoclose the last
        # tag on the stack. i don't ever allow multiple unclosed items on the
        # stack. so at worst one tag will be autoclosed and the previous one on
        # the stack will then become the parent.
        @stack.last << ast_node unless @stack.empty?

        # parse the tag's attributes.
        @stack << ast_node.attributes
        parse_attributes
        @stack.pop

        # now, maybe push the tag ast node onto the stack unless it's a void tag
        # or self closing. either way, grab the finish token so we can get a
        # final location object for the tag's ast node.
        case @lexer.lookahead.type
        when :CLOSE_CARET # ">"
          # a close caret means we keep the tag open so push it onto the stack,
          # unless it's one of the void tags like <br> or <hr>.
          finish_token = match(:CLOSE_CARET)
          @stack << ast_node unless type == :element && void_tag?(ast_node.name)
        when :FORWARD_SLASH_CLOSE_CARET # "/>"
          # if it's a /> then the tag is self closing so we don't need to push
          # it onto the stack since it's already closed.
          finish_token = match(:FORWARD_SLASH_CLOSE_CARET)
        else
          error "Expected to close the open tag with > or /> but instead got: #{@lexer.lookahead}"
        end

        # for now set the finish location to be the end of the open tag. if
        # there ends up being a corresponding closing tag down the road then
        # we'll update the finish location to be the end of the closing tag.
        ast_node.location.start = start_token.location.start.dup
        ast_node.location.finish = finish_token.location.finish.dup

        # and finally, return the new ast node to the caller
        ast_node
      end

      # Parses a close tag. If the last tag on the stack is not the
      # corresponding tag, this method will see if the previous tag can be auto
      # closed. If it can be autoclosed it will automatically be popped off the
      # stack (even without a close tag). Then it will look for the
      # corresponding open tag. If an open tag is not found on the stack an
      # error will be raised because it means we have a </div> close tag without a
      # corresponding <div> open tag.
      def parse_close_tag
        start_token = match(:OPEN_CARET_FORWARD_SLASH) # "</"

        case @lexer.lookahead.type
        when :TAG_NAMESPACE
          namespace_token = match(:TAG_NAMESPACE)
          name_token = match(:ELEMENT_NAME)
          type = :element
        when :ELEMENT_NAME
          name_token = match(:ELEMENT_NAME)
          type = :element
        when :VIEW_NAME
          name_token = match(:VIEW_NAME)
          type = :view
        else
          error "Expected to see a tag name but instead got: #{@lexer.lookahead}"
        end

        finish_token = match(:CLOSE_CARET)

        name = name_token.value
        namespace = namespace_token ? namespace_token.value : nil
        namespace_str = if namespace then namespace + ':' else ''; end
        close_tag = "</#{namespace_str}#{name}>"

        # If the user is trying to close a void tag we're not going to find it
        # on the stack. we could throw a parser error but i think this is a
        # silly part of the html spec and will be frustrating for users to have
        # to remember which tags they have to close vs which ones are
        # autoclosing. so let's just do the right thing here and forget we ever
        # saw this, shall we?
        return nil if void_tag?(name_token.value)

        # If the last tag on the stack is an AST::Tag and it is not the tag
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

      # Parses a comment and adds it to the last template or tag on the stack.
      def parse_comment
        token = match(:COMMENT)

        AST::Comment.new(
          token.value,
          with_default_options({location: token.location.dup})
        ).tap do |ast_node|
          @stack.last << ast_node unless @stack.empty?
        end
      end

      # Parses text and adds it to the last template or tag on the stack.
      def parse_text
        token = match(:TEXT)

        AST::Text.new(
          token.value,
          with_default_options({location: token.location.dup})
        ).tap do |ast_node|
          @stack.last << ast_node unless @stack.empty?
        end
      end

      def parse_attributes
        while @lexer.lookahead.type == :ATTRIBUTE_NAME
          parse_attribute
        end
      end

      def parse_attribute
        name_token = match(:ATTRIBUTE_NAME)

        name_node = AST::AttributeName.new(
          name_token.value,
          with_default_options({location: name_token.location.dup})
        )

        if @lexer.lookahead.type == :EQUALS
          match(:EQUALS)
          value_token = match(:ATTRIBUTE_VALUE)
          attr_location = Location.from_tokens(name_token, value_token)
          value_node = AST::AttributeValue.new(
            value_token.value,
            with_default_options({location: value_token.location.dup})
          )
        else
          attr_location = Location.from_tokens(name_token, name_token)
          value_node = nil
        end

        AST::Attribute.new(
          name_node,
          value_node,
          with_default_options({location: attr_location})
        ).tap do |ast_node|
          @stack.last << ast_node unless @stack.empty?
        end
      end

      def match(type, &block)
        token = @lexer.lookahead
        if token.type == type
          yield token if block_given?
          @lexer.scan
          return token
        else
          error "Expected #{type} but got #{token.type}."
        end
      end

      def with_default_options(**options)
        { source: @source, filepath: @filepath }.merge(options)
      end

      def error(msg = nil, location = nil)
        raise ParseError.new(msg, location, @source)
      end

      class << self
        def parse(io, opts = {})
          new(io, opts).parse
        end

        def parse_template(io, opts = {})
          new(io, opts).parse_template
        end
      end
    end

    class ParseError < StandardError
      def initialize(msg, location, source)
        super(msg)
        @location = location
        @source = source
      end
    end
  end
end
