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
      @parse_shortcuts = @context[:parse_shortcuts]
      
      @blocks = "" # same reason as why we rewrite 'store'
      extract_code(@text)
      
      # set whether the first paragraphe is spaced preserved.
      @in_space_pre = (@text[0..0] == ' ')
      enter(:void)
      
      unless @parse_shortcuts
        store '</p>' if @in_space_pre
        @text = RedCloth.new(@blocks).to_html
        @blocks = ""
        enter(:wiki)
      end
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
      if @text =~ /\A([^!"<\n]*)/m
        flush $&
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
        elsif !@in_space_pre && @text[0..2] == "\n\n " && !@parse_shortcuts
          # space preserving paragraphe
          @in_space_pre = true
          store "\n\n<p style='white-space:pre'>"
          eat 3
        elsif @in_space_pre && @text[0..1] == "\n\n" && !@parse_shortcuts
          store "</p>"
          flush "\n\n"
          @in_space_pre = false
        elsif @text[0..1] == "\n " && !@parse_shortcuts
          if @in_space_pre
            store "\n"
            eat 2
          else
            # forced line break
            store "\n<br/>"
            eat 2
          end
        elsif @text[0..0] == "\n"
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
        if @parse_shortcuts
          flush $&
        else
          eat $&
          if @context[:images]
            store @helper.make_gallery($1, :node=>@context[:node])
          else
            store @helper._('[gallery]')
          end
        end
      elsif @text =~ /\A\!([^0-9]{0,2})\{([^\}]*)\}\!/m
        # list of documents !<.{...}!
        #puts "DOCS:[#{$&}]"
        if @parse_shortcuts
          flush $&
        else
          eat $&
          if @context[:images]
            store @helper.list_nodes(:style=>$1, :ids=>$2, :node=>@context[:node])
          else
            store @helper._('[documents]')
          end
        end
      elsif @text =~ /\A\!([^0-9]{0,2}):([a-zA-Z-]+)(\+*)(\.([^\/\!]+)|)(\/([^\!]*)|)\!(:([^\s]+)|)/m
        # image !<.:art++.pv/blah blah!:12
        #puts "SHORCUT IMAGE:[#{$&}]"
        eat $&
        style, id, offset, other_opts, size, title, link = $1, $2, $3, $4, $5, $7, $9
        if node = @helper.find_node_by_shortcut(id,offset.size)
          if @parse_shortcuts
            if node.kind_of?(Document)
              # replace shortcut
              store "!#{style}#{node.zip}#{other_opts}!"
            else
              store $&
            end
          else
            if node.kind_of?(Document)
              store @helper.make_image(:style=>style, :id=>node[:zip].to_s, :node=>node, :size=>size, :title=>title, :link=>link, :images=>@context[:images])
            else
              store "[#{node.fullpath} is not a document]"
            end
          end
        elsif @parse_shortcuts
          store $&
        else
          store "[#{id}#{offset != '' ? offset.size+1 : ''} not found]"
        end
      elsif @text =~ /\A\!([^0-9]{0,2})([0-9]+)(\.([^\/\!]+)|)(\/([^\!]*)|)\!(:([^\s]+)|)/m
        # image !<.12.pv/blah blah!:12
        #puts "IMAGE:[#{$&}]"
        if @parse_shortcuts
          flush $&
        else
          eat $&
          store @helper.make_image(:style=>$1, :id=>$2, :size=>$4, :title=>$6, :link=>$8, :images=>@context[:images])
        end
      else
        #puts "EAT:[#{$&}]"
        # eat marker and continue scan
        flush @text[0..0]
      end
    end
    
    def scan_quote
      if @text =~ /\A"([^"]*)":([0-9]+[^\s]*)/m
        #puts "LINK:[#{$&}]"
        if @parse_shortcuts
          flush $&
        else
          eat $&
          # link inside the cms "":34
          title, id = $1, $2
          if id =~ /(.*?)#(.*)/
            id, sharp = $1, $2
            sharp = 'true' if sharp == ''
          end
          store @helper.make_link(:title=>title,:id=>id,:sharp=>sharp)
        end
      elsif @text =~ /\A"([^"]*)"::([a-zA-Z-]+)(\+*)([^\s]*)/m
        #puts "SHORTCUT_LINK:[#{$&}]"
        eat $&
        title, id, offset, mode = $1, $2, $3, $4
        if node = @helper.find_node_by_shortcut(id,offset.size)
          id = "#{node.zip}#{mode}"
          if @parse_shortcuts
            # replace shortcut
            store "\"#{title}\":#{id}"
          else
            title = node.fullpath
            if id =~ /(.*?)#(.*)/
              id, sharp = $1, $2
              sharp = 'true' if sharp == ''
            end
            store @helper.make_link(:title=>title,:id=>id,:sharp=>sharp,:node=>node)
          end
        elsif @parse_shortcuts
          store $&
        else
          store "[#{id}#{offset != '' ? offset.size+1 : ''} not found]"
        end
      else
        #puts "NOT A ZAZEN LINK"
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
        if @parse_shortcuts
          @escaped_code << $&
          block_counter += 1
          "\\ZAZENBLOCKCODE#{block_counter}ZAZENBLOCKCODE\\"
        else
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
        if @parse_shortcuts
          @escaped_code[$1.to_i]
        else
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
      end
      
      text.gsub!( /\\ZAZENBLOCKAT(\d+)ZAZENBLOCKAT\\/ ) do
        text = @escaped_at[$1.to_i]
        if @parse_shortcuts
          text
        else
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
end