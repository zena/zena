require 'rubygems'
require 'syntax/convertors/html'
require 'redcloth'
require File.join(File.dirname(__FILE__) , 'code_syntax')

module Zazen
  module Tags
    
    # This is not exactly how compile/render is meant to work with Parser, but there is no real need for a two step
    # rendering, so we compile here (enter(:void)) instead of doing this whith 'start'. This also lets us have the
    # context during compilation which is easier to manage the callbacks to the helper.
    def r_void
      @context = {:images => true, :pretty_code=>true}.merge(@context)
      @blocks = "" # same reason as why we rewrite 'store'
      extract_code(@text)
      
      # set whether the first paragraphe is spaced preserved.
      @in_space_pre = (@text[0..0] == ' ')
      enter(:void)
      store '</p>' if @in_space_pre

      puts @blocks.inspect
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
      puts "SCAN:[#{@text.inspect}]"
      if @text =~ /\A([^!"<\n]*)/m
        flush $&
        puts @text[0..3].inspect
        if @text[0..0] == '!'
          scan_exclam
        elsif @text[0..0] == '"'
          scan_quote
        elsif @text[0..4] == '<code'
          # FIXME: implement <code..> and @@ instead of "extract"
          flush
          # implement !! scan_code
        elsif @text[0..0] == '<'
          flush '<'
        elsif !@in_space_pre && @text[0..2] == "\n\n "
          # space preserving paragraphe
          @in_space_pre = true
          store "\n\n<p style='white-space:pre'>"
          eat 3
        elsif @in_space_pre && @text[0..1] == "\n\n"
          store "</p>"
          flush "\n\n"
          @in_space_pre = false
        elsif @text[0..1] == "\n "
          if @in_space_pre
            store "\n"
            eat 2
          else
            # forced line break
            store "\n<br/>"
            eat 2
          end
        elsif @text[0..0] == "\n"
          puts "HOHO"
          flush "\n"
        else
          # error
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
        #puts "GALLERY:[#{$&}]"
        eat $&
        if @context[:images]
          store @helper.make_gallery($1, :node=>@context[:node])
        else
          store @helper._('[gallery]')
        end
      elsif @text =~ /\A\!([^0-9]{0,2})\{([^\}]*)\}\!/m
        # list of documents !<.{...}!
        #puts "DOCS:[#{$&}]"
        eat $&
        if @context[:images]
          store @helper.list_nodes(:style=>$1, :ids=>$2, :node=>@context[:node])
        else
          store @helper._('[documents]')
        end
      elsif @text =~ /\A\!([^0-9]{0,2})([0-9]+)(\.([^\/\!]+)|)(\/([^\!]*)|)\!(:([^\s]+)|)/m
        # image !<.12.pv/blah blah!:12
        #puts "IMAGE:[#{$&}]"
        eat $&
        store @helper.make_image(:style=>$1, :id=>$2, :size=>$4, :title=>$6, :link=>$8, :images=>@context[:images])
      else
        #puts "EAT:[#{$&}]"
        # eat marker and continue scan
        flush @text[0..0]
      end
    end
    
    def scan_quote
      if @text =~ /\A"([^"]*)":([0-9]+[^\s]*)/m
        #puts "LINK:[#{$&}]"
        eat $&
        # link inside the cms "":34
        title, id = $1, $2
        if id =~ /(.*?)#(.*)/
          id, sharp = *id.split('#')
          sharp = title if sharp.nil? || sharp == ''
        end
        store @helper.make_link(:title=>title,:id=>id,:sharp=>sharp)
      else
        #puts "NOT_LINK"
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
        #puts "WIKI:[#{$&}]"
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
    
      @escaped_at = []
      block_counter = -1
      text.gsub!( /(\A|[^\w])@(.*?)@(\Z|[^\w])/m ) do
        @escaped_at << $2
        block_counter += 1
        "#{$1}\\ZAZENBLOCKAT#{block_counter}ZAZENBLOCKAT\\#{$3}"
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