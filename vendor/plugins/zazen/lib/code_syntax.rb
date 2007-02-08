require 'syntax'

module Syntax
  # changed 'Token' class to make recursive calls possible
  class Token < String

    # the type of the lexeme that was extracted.
    attr_reader :group

    # the instruction associated with this token (:none, :region_open, or
    # :region_close)
    attr_reader :instruction
    
    # true if this token's html tags should be escaped
    attr_reader :escape

    # Create a new Token representing the given text, and belonging to the
    # given group.
    def initialize( text, group, instruction = :none, escape = true )
      super text
      @group = group
      @instruction = instruction
      @escape = escape
    end
  end
  
  class Tokenizer
    private
    def subgroup( gr, data )
      flush_chunk
      @callback.call( Token.new( data, gr, :none, false ) )
    end
  end
  
  module Convertors

    # A simple class for converting a text into HTML.
    class HTML < Abstract

      # Converts the given text to HTML, using spans to represent token groups
      # of any type but <tt>:normal</tt> (which is always unhighlighted). If
      # +pre+ is +true+, the html is automatically wrapped in pre tags.
      def convert( text, pre=true )
        html = ""
        html << "<pre>" if pre
        regions = []
        @tokenizer.tokenize( text ) do |tok|
          value = tok.escape ? html_escape(tok) : tok
          case tok.instruction
            when :region_close then
              regions.pop
              html << "</span>"
            when :region_open then
              regions.push tok.group
              html << "<span class=\"#{tok.group}\">#{value}"
            else
              if tok.group == ( regions.last || :normal )
                html << value
              else
                html << "<span class=\"#{tok.group}\">#{value}</span>"
              end
          end
        end
        html << "</span>" while regions.pop
        html << "</pre>" if pre
        html
      end
    end
  end
end

class ZafuTokenizer < Syntax::Tokenizer
  def step
    if methods = scan(/<\/?z:[^>]+>/)  
      methods =~ /<(\/?)z:([^> ]+)([^>]*)(\/?)>/
      start_group :punct, "<#{$1}z:"
      start_group :ztag, $2
      trailing = $4
      params = $3.strip.split(/ +/)
      params.each do |kv|
        key, value = *(kv.split('='))
        append " "
        start_group :param, key
        append "="
        start_group :value, value
      end
      start_group :punct, "#{trailing}>"
    elsif html = scan(/<\/?[^>]+>/)
      html =~/<\/?([^>]+)>/
      start_group :tag, html
    else
      start_group :normal, scan(/./m)
    end
  end
end
Syntax::SYNTAX['zafu'] = ZafuTokenizer


class ErbTokenizer < Syntax::Tokenizer
  def step
    if methods = scan(/<%[^>]+%>/m)  
      methods =~ /<%(=?)([^>]+?)(-?)%>/m
      start_group :punct, "<%#{$1}"
      trailing = $3
      subgroup :expr, "<pre class='ruby'>#{Syntax::Convertors::HTML.for_syntax('ruby').convert($2, false)}</pre>"
      start_group :punct, "#{trailing}%>"
    elsif html = scan(/<\/?[^>]+>/)
      html =~/<\/?([^>]+)>/
      start_group :tag, html
    else
      start_group :normal, scan(/./m)
    end
  end
end
Syntax::SYNTAX['erb'] = ErbTokenizer


class ShTokenizer < Syntax::Tokenizer
  def step
    if variables = scan(/\$\w+/)
      start_group :variable, variables
    elsif start = scan(/# \S+/)
      start_group :punct, '# '
      start_group :method, start[2..-1]
    elsif start = scan(/\$ \S+/)
      start_group :root, '$ '
      start_group :method, start[2..-1]
    else
      start_group :normal, scan(/./m)
    end
  end
end
Syntax::SYNTAX['sh'] = ShTokenizer


