require 'rubygems'
require 'syntax/convertors/html'
require 'redcloth'
require File.join(File.dirname(__FILE__) , 'code_syntax')

module Zazen
  module Tags
    
    # This is not exactly how compile/render is meant to work with Parser, but there is no real need for a two step
    # rendering, so we compile here (enter(:void)) instead of doing this whith 'start'. This also lets us have the
    # context during compilation which makes it easier to manage the callbacks to the helper.
    def r_void
      @context = {:images => true, :pretty_code=>true, :output => 'html'}.merge(@context)
      @parse_shortcuts = @context[:parse_shortcuts]
      @text = @text.gsub("\r\n","\n") # this also creates our own 'working' copy of the text
      @blocks = "" # same reason as why we rewrite 'store'
      
      extract_code(@text)
      
      # set whether the first paragraphe is spaced preserved.
      @in_space_pre = (@text[0..0] == ' ')
      
      enter(:void) # <== parse here
      
      unless @parse_shortcuts
        store '</pre>' if @in_space_pre
        
        case @context[:output]
        when 'html'
          # TODO: we should write our own parser for textile with rendering formats...
          @text = RedCloth.new(@blocks).to_html
        when 'latex'
          # replace RedCloth markup by latex equivalent
          @text = RedCloth.new(@blocks).to_latex
        end
        
        # Replace placeholders by their real values
        @helper.replace_placeholders(@text) if @helper.respond_to?('replace_placeholders')
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
      if @text =~ /\A([^!"<\n\[]*)/m
        flush $&
        if @text[0..0] == '!'
          scan_exclam
        elsif @text[0..0] == '"'
          scan_quote
        elsif @text[0..0] == '['
          scan_bracket
        elsif @text[0..4] == '<code'
          # FIXME: implement <code..> and @@ instead of "extract"
          flush
          # implement !! scan_code
        elsif @text[0..0] == '<'
          flush '<'
        elsif !@in_space_pre && @text[0..2] == "\n\n " && !@parse_shortcuts
          # space preserving paragraphe
          @in_space_pre = true
          store "\n\n<pre>"
          eat 3
        elsif @in_space_pre && @text[0..1] == "\n\n" && !@parse_shortcuts
          store "</pre>"
          while @text[0..0] == "\n"
            flush "\n"
          end
          @in_space_pre = false
        elsif @text[0..1] == "\n\n"
          while @text[0..0] == "\n"
            flush "\n"
          end
        elsif @text[0..1] == "\n " && @in_space_pre && !@parse_shortcuts
          store "\n"
          eat 2
        elsif @text[0..1] == "\n|"
          flush "\n|"
        elsif @text[0..0] == "\n" && !@parse_shortcuts
          if @in_space_pre || @text == "\n" || @text[1..1] == '*' || @text[1..1] == '#'
            flush "\n"
          else
            # forced line break
            store "\n<br/>"
            eat 1
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
        eat $&
        if @context[:images]
          ids = parse_document_ids($1)
          if @parse_shortcuts
            store "![#{ids.join(',')}]!"
          else
            store @helper.make_gallery(ids, :node=>@context[:node])
          end
        else
          store @helper._('[gallery]')
        end
      elsif @text =~ /\A\!([^0-9]{0,2})\{([^\}]*)\}\!/m
        # list of documents !<.{...}!
        #puts "DOCS:[#{$&}]"
        eat $&
        style, ids = $1, $2
        if @context[:images]
          ids = parse_document_ids(ids)
          if @parse_shortcuts
            store "!#{style}{#{ids.join(',')}}!"
          else
            store @helper.list_nodes(ids, :style=>style, :node=>@context[:node])
          end
        else
          store @helper._('[documents]')
        end
      elsif @text =~ /\A\!([^0-9]{0,2}):([a-zA-Z-]+)(\+*)(\.([^\/\!]+)|)(\/([^\!]*)|)\!(:([^\s]+)|)/m
        # image !<.:art++.pv/blah blah!:12
        #puts "SHORCUT IMAGE:[#{$&}]"
        eat $&
        style, id, offset, other_opts, mode, title_opts, title, link = $1, $2, $3, $4, $5, $6, $7, $9
        if node = @helper.find_node_by_shortcut(id,offset.size)
          
          if link && link =~ /^:([a-zA-Z-]+)(\+*)(.*)$/
            rest = $3
            if link_node = @helper.find_node_by_shortcut($1,$2.size)
              link = link_node[:zip].to_s + rest
            end
          end
          
          if @parse_shortcuts
            if node.kind_of?(Document)
              # replace shortcut
              store "!#{style}#{node.zip}#{other_opts}#{title_opts}!#{link ? ':' + link : ''}"
            else
              store $&
            end
          else
            if node.kind_of?(Document)
              store @helper.make_image(:style=>style, :id=>node[:zip].to_s, :node=>node, :mode=>mode, :title=>title, :link=>link, :images=>@context[:images])
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
        eat $&
        style, id, other_opts, mode, title_opts, title, link = $1, $2, $3, $4, $5, $6, $8
        if link && link =~ /^:([a-zA-Z-]+)(\+*)(.*)/
          rest = $3
          if link_node = @helper.find_node_by_shortcut($1,$2.size)
            link = link_node[:zip].to_s + rest
          end
        end
        if @parse_shortcuts
          store "!#{style}#{id}#{other_opts}#{title_opts}!#{link ? ':' + link : ''}"
        else
          store @helper.make_image(:style=>style, :id=>id, :mode=>mode, :title=>title, :link=>link, :images=>@context[:images])
        end
      else
        #puts "EAT:[#{$&}]"
        # eat marker and continue scan
        flush @text[0..0]
      end
    end
    
    def scan_quote
      if @text =~ /\A"([^"]*)":([0-9]+(_[a-z]+|)(\.[a-z]+|)(#[a-z_\/\[\]]*|))/m
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
      elsif @text =~ /\A"([^"]*)"::([a-zA-Z-]+)(\+*)((_[a-z]+|)(\.[a-z]+|)(#[a-z_\/\[\]]*|))/m
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
    
    def scan_bracket
      # puts "BRACKET:[#{@text}]"
      if @text =~ /\A\[(\w+)\](.*?)\[\/\1\]/m
        if @parse_shortcuts
          flush $&
        else
          eat $&
          # [math]....[/math] (we do not use <math> to avoid confusion with mathml)
          store @helper.make_asset(:asset_type => $1, :content => $2, :node => @options[:node], :preview => @context[:preview], :output => @context[:output])
        end
      else
        # nothing interesting
        flush '['
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
      if @text =~ /\A\?(\w[^\?]*?\w)\?([^\w:]|:([^\s<]+))/m
        #puts "WIKI:[#{$&}]"
        eat $&
        title = $1
        url   = $3
        # wiki reference ?zafu? or ?zafu?:http://...
        if url
          if url =~ /[^\w0-9]$/
            # keep trailing punctuation
            store @helper.make_wiki_link(:title=>title, :url=>url[0..-2], :node=>@context[:node]) + $&
          else
            store @helper.make_wiki_link(:title=>title, :url=>url, :node=>@context[:node])
          end
        else
          store @helper.make_wiki_link(:title=>title, :node=>@context[:node]) + $2
        end
      else
        # false alert
        flush @text[0..0]
      end
    end
    
    
    def extract_code(fulltext)
      @escaped_code = []
      block_counter = -1
      fulltext.gsub!( /<code([^>]*)>(.*?)<\/code>/m ) do
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
      fulltext.gsub!( /(\A|[^\w])@(.*?)@(\Z|[^\w])/m ) do
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
          lang, code = *(@escaped_code[$1.to_i])
          if lang != ''
            code_tag = "<code class='#{lang}'>"
          else
            code_tag = '<code>'
          end
          if Syntax::SYNTAX[lang] != Syntax::Default && @context[:pretty_code]
            convertor = Syntax::Convertors::HTML.for_syntax(lang)
            "#{code_tag}#{convertor.convert( code, false )}</code>"
          else
            RedCloth.new("#{code_tag}#{code}</code>").to_html
          end
          #code_tag + code.gsub(/\n( *)/m) { "<br/>\n" + ('&nbsp;' * $1.length) } + '</code>'
        end
      end
      
      text.gsub!( /\\ZAZENBLOCKAT(\d+)ZAZENBLOCKAT\\/ ) do
        code = @escaped_at[$1.to_i]
        if @parse_shortcuts
          '@'+code+'@'
        else
          if code =~ /^(\w+)\|/ && Syntax::SYNTAX[$1]
            lang = $1
            if @context[:pretty_code]
              convertor = Syntax::Convertors::HTML.for_syntax(lang)
              res = convertor.convert( code[(lang.length+1)..-1], false )
            else
              res = code[(lang.length+1)..-1]
            end
            res = "<code class='#{lang}'>#{res}</code>"
          else
            res = RedCloth.new("<code>#{code}</code>").to_html
          end
          res
        end
      end
    end
    
    def parse_document_ids(str)
      str.split(',').map do |id|
        if id =~ /\A:([a-zA-Z-]+)(\+*)/
          id, offset = $1, $2
          if node = @helper.find_node_by_shortcut(id.strip,offset.size)
            if node.kind_of?(Document)
              # replace shortcut
              node.zip
            elsif @parse_shortcuts
              id  # not a document but do not remove
            else
              nil # not a document
            end
          elsif @parse_shortcuts
            ":#{id}#{offset}"
          else
            nil # document not found
          end
        else
          id
        end
      end.compact
    end
  end
end