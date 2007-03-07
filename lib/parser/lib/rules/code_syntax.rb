require 'rubygems'
require 'syntax/convertors/html'
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
    
    def parse_params(text)
      return [] unless text
      params = []
      rest = text.strip
      while (rest != '')
        if rest =~ /(.+?)=/
          key = $1.strip.to_sym
          rest = rest[$&.length..-1].strip
          if rest =~ /('|")([^\1]*?[^\\])\1/
            rest = rest[$&.length..-1].strip
            if $1 == "'"
              params << [key,$2.gsub("\\'", "'")]
            else
              params << [key,$2.gsub('\\"', '"')]
            end
          else
            # error, bad format, return found params.
            break
          end
        else
          # error, bad format
          break
        end
      end
      params
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
    if ztag = scan(/\A<\/?z:[^>]+>/)  
      ztag =~ /<(\/?)z:([^> ]+)([^>]*)(\/?)>/
      start_group :tag, "<#{$1}z:"
      start_group :ztag, $2
      trailing = $4
      params = parse_params($3)
      params.each do |k,v|
        append " "
        if v =~ /[^\\]'/
          v = "\"#{v}\""
        else
          v = "'#{v}'"
        end
        start_group :param, k.to_s
        append '='
        start_group :value, v
      end
      start_group :tag, "#{trailing}>"
    elsif dotag = scan(/<([^>]+)do\s*=([^>]+)>/)
        if dotag =~ /\A<(\w+)([^>]*?)do\s*=('|")([^\3]*?[^\\])\3([^>]*?)(\/?)>/
          start_group :tag, "<#{$1}#{$2}"
          start_group :tag, "do="
          start_group :ztag, "'#{$4}'"
          trailing = $6
          params = parse_params($5)
          params.each do |k,v|
            append " "
            if v =~ /[^\\]'/
              v = "\"#{v}\""
            else
              v = "'#{v}'"
            end
            if k == :do
              start_group :tag, k.to_s
              append '='
              start_group :ztag, v
            else
              start_group :param, k.to_s
              append '='
              start_group :value, v
            end
          end
          start_group :tag, "#{trailing}>"
        else
          start_group :normal, dotag
        end
    elsif html = scan(/\A<\/?[^>]+>/)
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
      subgroup :expr, "<code class='ruby'>#{Syntax::Convertors::HTML.for_syntax('ruby').convert($2, false)}</code>"
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


