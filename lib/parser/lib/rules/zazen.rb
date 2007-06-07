require 'rubygems'
require 'syntax/convertors/html'
require 'redcloth'
require File.join(File.dirname(__FILE__) , 'code_syntax')

module Zazen
  module Tags
    def r_void
      @context = {:images => true, :pretty_code=>true}.merge(@context)
      @blocks = "" # same reason as why we rewrite 'store'
      extract_code(@text)
      enter(:void)
      @text = RedCloth.new(@blocks).to_html
      @blocks = ""
      enter(:wiki)
      render_code(@blocks)
      @blocks
    end
  end
end

module Zazen
  module Rules
    def start(mode)
      @helper = @options[:helper]
      # we do nothing, everything is done when 'render' is called
    end
    
    # rewrite store to optimize for our 'text only' parser
    def store(str)
      @blocks << str
    end
    
    def flush(str=@text)
      @blocks << str
      @text = @text[str.length..-1]
    end
    
    def scan
      #puts "SCAN:[#{@text}]"
      if @text =~ /\A([^!"<]*)/m
        flush $&
        if @text[0..0] == '!'
          scan_exclam
        elsif @text[0..0] == '"'
          scan_quote
        elsif @text[0..4] == '<code'
          # FIXME: implement instead of "extract"
          flush
          # implement !! scan_code
        elsif @text =~ /\A([^>]*)>/m
          flush $&
        else
          # error never closed tag
          flush
        end
      else
        # nothing interesting
        flush
      end
    end
    
    def scan_exclam
      #puts "EXCL:[#{@text}]"
      if @text =~ /\A\!\[([^\]]*)\]\!/m
        # create a gallery ![...]!
        eat $&
        if @context[:images]
          store @helper.make_gallery($1)
        else
          store @helper._('[gallery]')
        end
      elsif @text =~ /\A\!([^0-9]{0,2})\{([^\}]*)\}\!/m
        # list of documents !<.{...}!
        eat $&
        if @context[:images]
          store @helper.list_nodes(:style=>$1, :ids=>$2)
        else
          store @helper._('[documents]')
        end
      elsif @text =~ /\A\!([^0-9]{0,2})([0-9]+)(\.([^\/\!]+)|)(\/([^\!]*)|)\!(:([^\s]+)|)/m
        # image !<.12.pv/blah blah!:12
        #puts "IMAGE:[#{$&}]"
        eat $&
        store @helper.make_image(:style=>$1, :id=>$2, :size=>$4, :title=>$6, :link=>$8, :images=>@context[:images])
      else
        # eat marker and continue scan
        flush @text[0..0]
      end
    end
    
    def scan_quote
      if @text =~ /\A"([^"]*)":([0-9]+[^\s]*)/m
        eat $&
        # link inside the cms "":34
        title, id = $1, $2
        if id =~ /(.*?)#(.*)/
          id, sharp = *id.split('#')
          sharp = title if sharp.nil? || sharp == ''
        end
        store @helper.make_link(:title=>title,:id=>id,:sharp=>sharp)
      else
        flush @text[0..0]
      end
    end
    
    def scan_wiki
      #puts "WIKI:[#{@text}]"
      if @text =~ /\A([^\?])*/m
        flush $&
        scan_wiki_link
      else
        # nothing interesting
        flush
      end
    end
    
    def scan_wiki_link
      if @text =~ /\A\?(\w[^\?]+?\w)\?([^\w:]|:([^\s<]+))/m
        eat $&
        title = $1
        url   = $3
        # wiki reference ?zafu? or ?zafu?:http://...
        if url
          if url =~ /[^\w0-9]$/
            # keep trailing punctuation
            store @helper.make_wiki_link(:title=>title, :url=>url[0..-2]) + $&
          else
            store @helper.make_wiki_link(:title=>title, :url=>url)
          end
        else
          store @helper.make_wiki_link(:title=>title) + $2
        end
      else
        # false alert
        flush @text[0..0]
      end
    end
    
    
    def extract_code(text)
      @escaped_at = []
      block_counter = -1
      text.gsub!( /(\A|[^\w])@(.*?)@(\Z|[^\w])/m ) do
        @escaped_at << $2
        block_counter += 1
        "#{$1}\\ZAZENBLOCKAT#{block_counter}ZAZENBLOCKAT\\#{$3}"
      end
  
      @escaped_code = []
      block_counter = -1
      text.gsub!( /<code([^>]*)>(.*?)<\/code>/m ) do
        params, text = $1, $2
        divparams = []
        if params =~ /\A(.*)lang\s*=\s*("|')([^"']+)\2(.*)\Z/m
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
    
    def render_code(text)
      text.gsub!( /\\ZAZENBLOCKCODE(\d+)ZAZENBLOCKCODE\\/ ) do
        lang, text = *(@escaped_code[$1.to_i])
        if lang != ''
          code_tag = "<code class='#{lang}'>"
        else
          code_tag = '<code>'
        end
        if Syntax::SYNTAX[lang] && @context[:pretty_code]
          convertor = Syntax::Convertors::HTML.for_syntax(lang)
          "#{code_tag}#{convertor.convert( text, false ).gsub(/\n( *)/m) { "<br/>\n" + ('&nbsp;' * $1.length) }}</code>"
        else
          RedCloth.new("#{code_tag}#{text}</code>").to_html
        end
      end
      
      text.gsub!( /\\ZAZENBLOCKAT(\d+)ZAZENBLOCKAT\\/ ) do
        text = @escaped_at[$1.to_i]
        if text =~ /^(\w+)\|/ && Syntax::SYNTAX[$1]
          lang = $1
          if @context[:pretty_code]
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