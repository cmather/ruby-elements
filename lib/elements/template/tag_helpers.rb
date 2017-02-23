require "set"

module Elements
  module Template
    module TagHelpers
      NAMESPACES = {
        html: "http://www.w3.org/1999/xhtml",
        svg: "http://www.w3.org/2000/svg",
        math: "http://www.w3.org/1998/Math/MathML"
      }

      HTML_TAGS = Set.new(%w{
        html body base head link meta style title
        address article aside footer header h1 h2 h3 h4 h5 h6 hgroup nav section
        div dd dl dt figcaption figure hr img li main ol p pre ul
        a b abbr bdi bdo br cite code data dfn em i kbd mark q rp rt rtc ruby
        s samp small span strong sub sup time u var wbr area audio map track video
        embed object param source canvas script noscript del ins
        caption col colgroup table thead tbody td th tr
        button datalist fieldset form input label legend meter optgroup option
        output progress select textarea
        details dialog menu menuitem summary
        content element shadow template
      })

      VOID_TAGS = Set.new(%w{
        area base br col embed hr img input keygen link meta param source track wbr
      })

      RAW_TEXT_TAGS = Set.new(%w{
        script style
      })

      ESCAPABLE_RAW_TEXT_TAGS = Set.new(%w{
        textarea title
      })

      # https://html.spec.whatwg.org/multipage/dom.html#phrasing-content
      PHRASING_CONTENT_TAGS = Set.new(%w{
        a abbr area audio b bdi bdo br button canvas cite code data datalist del dfn em
        embed i iframe img input ins kbd keygen label map mark math meter noscript object
        output progress q ruby s samp script select small span strong sub sup svg template
        textarea time u var video wbr
      })

      # https://www.w3.org/TR/html5/syntax.html#optional-tags
      # The keys in this hash represent some last tag. The values (the sets) are
      # the tags who will automatically close the last tag. For example, if you
      # leave a <p> tag open without closing it and we encounter one of the tags
      # in the set (e.g. address, article, etc) then we will automatically close
      # the prior <p> tag.
      IMPLIED_END_TAGS = {
        "li" => Set.new(%w{li}),
        "dt" => Set.new(%w{dt dd}),
        "dd" => Set.new(%w{dt dd}),
        "p" => Set.new(%w{
          address article aside blockquote div dl
          fieldset footer form h1 h2 h3 h4 h5 h6
          header hgroup hr main nav ol p pre section
          table ul
        })
      }

      def html_tag?(tag)
        HTML_TAGS.include?(tag)
      end

      # Void tags close themselves automatically.
      def void_tag?(tag)
        VOID_TAGS.include?(tag)
      end

      # Returns true if the last_tag can be closed automatically. There are two
      # cases: If new_tag is provided then we see if the new tag can close the
      # old tag. If no new_tag is provided we see if the tag is automatically
      # closable at the end of its parent's list of children.
      def can_auto_close_tag?(tag, new_tag = nil)
        if new_tag
          IMPLIED_END_TAGS.has_key?(tag) && IMPLIED_END_TAGS[tag].include?(new_tag)
        else
          IMPLIED_END_TAGS.has_key?(tag)
        end
      end
    end
  end
end
