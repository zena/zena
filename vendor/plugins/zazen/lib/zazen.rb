require 'rubygems'
require 'syntax/convertors/html'
require 'redcloth'
require File.join(File.dirname(__FILE__) , 'code_syntax')

module Zazen
  class Parser
    attr_accessor :text, :options, :helper
    @@rules = []
    @@after_rules = []
    class << self
      def add_rule(regex, &block)
        @@rules << [regex, block]
      end
      def add_after_rule(regex, &block)
        @@after_rules << [regex, block]
      end
    end
    
    def initialize(text)
      @text   = text
      @last_match = {}
      @options = {}
    end

    def render(options)
      @options = {:images => true, :pretty_code=>true}.merge(options)
      @helper = options[:helper]
      extract_code
      render_zazen(@@rules)
      render_markup
      render_code
      render_zazen(@@after_rules)
      @text
    end
    
    def [](key)
      if key.kind_of?(Symbol)
        @options[key]
      else
        @last_match[key]
      end
    end

    private

    def extract_code
      @escaped_at = []
      block_counter = -1
      @text.gsub!( /(\A|[^\w])@(.*?)@(\Z|[^\w])/ ) do
        @escaped_at << $2
        block_counter += 1
        "#{$1}\\ZAZENBLOCKAT#{block_counter}ZAZENBLOCKAT\\#{$3}"
      end
  
      @escaped_code = []
      block_counter = -1
      @text.gsub!( /<code([^>]*)>(.*?)<\/code>/m ) do
        params, text = $1, $2
        divparams = []
        if params =~ /^(.*)lang\s*=\s*("|')([^"']+)\2(.*)$/
          pre, lang, post = $1.strip, $3, $4.strip
          divparams << pre if pre && pre != ""
          divparams << post if post && post != ""
        else
          divparams << params.strip if params != ''
          lang = ''
        end
        #divparams << "class='code'" unless params =~ /class\s*=/
        divparams.unshift('') if divparams != []
        @escaped_code << [lang, text]
        block_counter += 1
        "<pre#{divparams.join(' ')}>\\ZAZENBLOCKCODE#{block_counter}ZAZENBLOCKCODE\\</pre>"
      end
    end
    
    def render_zazen(rules)
      rules.each do |regex, block|
        @text.gsub!(regex) do
          @last_match = $~
          block.call(self)
        end
      end
    end
    
    def render_markup
      @text = RedCloth.new(@text).to_html
    end
    
    def render_code
      @text.gsub!( /\\ZAZENBLOCKCODE(\d+)ZAZENBLOCKCODE\\/ ) do
        lang, text = *(@escaped_code[$1.to_i])
        if lang != ''
          pre_tag = "<code class='#{lang}'>"
        else
          pre_tag = '<code>'
        end
        if Syntax::SYNTAX[lang] && @options[:pretty_code]
          convertor = Syntax::Convertors::HTML.for_syntax(lang)
          "#{pre_tag}#{convertor.convert( text, false )}</pre>"
        else
          RedCloth.new("#{pre_tag}#{text}</pre>").to_html
        end
      end
      
      @text.gsub!( /\\ZAZENBLOCKAT(\d+)ZAZENBLOCKAT\\/ ) do
        text = @escaped_at[$1.to_i]
        if text =~ /^(\w+)\|/ && Syntax::SYNTAX[$1]
          lang = $1
          if @options[:pretty_code]
            convertor = Syntax::Convertors::HTML.for_syntax(lang)
            res = convertor.convert( text[(lang.length+1)..-1], false )
          else
            res = text[(lang.length+1)..-1]
          end
          res = "<code class='#{lang}'>#{res}</code>"
        else
          res = RedCloth.new("<code>#{text}</code>").to_html
        end
        res
      end
    end
  end
end

# create a gallery ![...]!
Zazen::Parser.add_rule( /\!\[([^\]]*)\]\!/ ) do |parse|
  if parse[:images]
    parse.helper.make_gallery(parse[1])
  else
    parse.helper.trans('[gallery]')
  end
end

# list of documents !<.{...}!
Zazen::Parser.add_rule( /\!([^0-9]{0,2})\{([^\}]*)\}\!/ ) do |parse|
  if parse[:images]
    parse.helper.list_nodes(:style=>parse[1], :ids=>parse[2])
  else
    parse.helper.trans('[documents]')
  end
end

# image !<.12.pv/blah blah!:12
Zazen::Parser.add_rule( /\!([^0-9]{0,2})([0-9]+)(\.([^\/\!]+)|)(\/([^\!]*)|)\!(:([^\s]+)|)/ ) do |parse|
  parse.helper.make_image(:style=>parse[1], :id=>parse[2], :size=>parse[4], :title=>parse[6], :link=>parse[8], :images=>parse[:images])
end

# link inside the cms "":34
Zazen::Parser.add_rule( /"([^"]*)":([0-9]+)/ ) do |parse|
  parse.helper.make_link(:title=>parse[1],:id=>parse[2])
end

# wiki reference ?zafu? or ?zafu?:http://...
Zazen::Parser.add_after_rule( /\?(\w[^\?]+?\w)\?([^\w:]|:([^\s]+))/ ) do |parse|
  if parse[3]
    if parse[3] =~ /([^\w0-9])$/
      parse.helper.make_wiki_link(:title=>parse[1], :url=>parse[3][0..-2]) + $1
    else
      parse.helper.make_wiki_link(:title=>parse[1], :url=>parse[3])
    end
  else
    parse.helper.make_wiki_link(:title=>parse[1]) + parse[2]
  end
end