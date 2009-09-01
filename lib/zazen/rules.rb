require 'code/syntax'

module Zazen
  module Rules
    include Zena::Acts::Secure
    
    PSEUDO_ID_REGEXP = ":[0-9a-zA-Z-]+\\+*|\\([^\\)]*\\)"
    
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
      if @text =~ /\A([^\|!"<\n\[]*)/m
        flush $&
        if @text[0..0] == '!'
          scan_exclam
        elsif @text[0..0] == '"'
          scan_quote
        elsif @text[0..0] == '['
          scan_bracket
        elsif @text[0..0] == '|'
          scan_pipe
        elsif @text[0..4] == '<code'
          # FIXME: implement <code..> and @@ instead of "extract"
          flush
          # implement !! scan_code
        elsif @text[0..0] == '<'
          flush '<'
        elsif !@in_space_pre && @text[0..2] == "\n\n " && !@translate_ids
          # space preserving paragraphe
          @in_space_pre = true
          store "\n\n<pre>"
          eat 3
        elsif @in_space_pre && @text[0..1] == "\n\n" && !@translate_ids
          store "</pre>"
          while @text[0..0] == "\n"
            flush "\n"
          end
          @in_space_pre = false
        elsif @text[0..1] == "\n\n"
          while @text[0..0] == "\n"
            flush "\n"
          end
        elsif @text[0..1] == "\n " && @in_space_pre && !@translate_ids
          store "\n"
          eat 2
        elsif @text[0..1] == "\n|"
          flush "\n|"
        elsif @text[0..0] == "\n" && !@translate_ids
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
          if @translate_ids
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
          if @translate_ids
            store "!#{style}{#{ids.join(',')}}!"
          else
            store @helper.list_nodes(ids, :style=>style, :node=>@context[:node])
          end
        else
          store @helper._('[documents]')
        end
      elsif @text =~ /\A\!([^0-9]{0,2})(#{PSEUDO_ID_REGEXP})(_([^\/\!]+)|)(\/([^\!]*)|)\!(:([^\s]+)|)/m
        # image !<.:art++_pv/blah blah!:12
        #puts "SHORCUT IMAGE:#{$~.to_a.inspect}"
        eat $&
        style, id, other_opts, mode, title_opts, title, link = $1, $2, $3, $4, $5, $6, $8
        if node = find_node_by_pseudo(id)
          if link && link =~ /^(#{PSEUDO_ID_REGEXP})(.*)$/
            rest = $2
            if link_node = find_node_by_pseudo($1)
              link = link_node.pseudo_id(@context[:node], @translate_ids || :zip).to_s + rest
            end
          end
          
          if @translate_ids
            if node.kind_of?(Document)
              # replace shortcut
              store "!#{style}#{node.pseudo_id(@context[:node], @translate_ids || :zip)}#{other_opts}#{title_opts}!#{link ? ':' + link : ''}"
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
        elsif @translate_ids
          store $&
        else
          store "[#{id} not found]"
        end
      elsif @text =~ /\A\!([^0-9]{0,2})([0-9]+)(_([^\/\!]+)|)(\/([^\!]*)|)\!(:([^\s]+)|)/m
        # image !<.12_pv/blah blah!:12
        #puts "IMAGE:[#{$&}]"
        eat $&
        style, id, other_opts, mode, title_opts, title, link = $1, $2, $3, $4, $5, $6, $8
        if link && link =~ /^(#{PSEUDO_ID_REGEXP})(.*)$/
          rest = $2
          if link_node = find_node_by_pseudo($1)
            link = link_node[:zip].to_s + rest
          end
        end
        if @translate_ids
          if @translate_ids != :zip
            node = find_node_by_pseudo(id)
            id = node.pseudo_id(@context[:node], @translate_ids) if node
          end
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
        if @translate_ids == :zip
          flush $&
        elsif @translate_ids
          eat $&
          title, id = $1, $2
          node = find_node_by_pseudo(id)
          id = node.pseudo_id(@context[:node], @translate_ids) if node
          store "\"#{title}\":#{id}"
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
      elsif @text =~ /\A"([^"]*)":(#{PSEUDO_ID_REGEXP})((_[a-z]+|)(\.[a-z]+|)(#[a-z_\/\[\]]*|))/m
        #puts "SHORTCUT_LINK:[#{$&}]"
        eat $&
        title, pseudo_id, mode_format, mode, format, dash = $1, $2, $3, $4, $5, $6
        if node = find_node_by_pseudo(pseudo_id)
          if @translate_ids
            id = "#{node.pseudo_id(@context[:node], @translate_ids)}#{mode_format}"
            # replace shortcut
            store "\"#{title}\":#{id}"
          else
            id = "#{node.zip}#{mode_format}"
            if format == '.data'
              title = "#{node.fullpath}#{mode}.#{node.c_ext}#{dash}"
            else
              title = "#{node.fullpath}#{mode_format}"
            end
            if id =~ /(.*?)#(.*)/
              id, sharp = $1, $2
              sharp = 'true' if sharp == ''
            end
            store @helper.make_link(:title=>title,:id=>id,:sharp=>sharp,:node=>node)
          end
        elsif @translate_ids
          store $&
        else
          pseudo_id = pseudo_id[1..-1] if pseudo_id[0..0] == ':'
          store "[#{pseudo_id} not found]"
        end
      else
        #puts "NOT A ZAZEN LINK"
        flush @text[0..0]
      end
    end
    
    def scan_bracket
      # puts "BRACKET:[#{@text}]"
      if @text =~ /\A\[(\w+)\](.*?)\[\/\1\]/m
        if @translate_ids
          flush $&
        else
          eat $&
          # [math]....[/math] (we do not use <math> to avoid confusion with mathml)
          store @helper.make_asset(:asset_tag => $1, :content => $2, :node => @context[:node], :preview => @context[:preview], :output => @context[:output])
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
    
    def scan_pipe
      #puts "PIPE:[#{@text}]"
      if @text =~ /\A\|([<=>]\.|)([0-9]+\.|)([a-zA-Z_]+)(\/([^\|]*)|)\|/m
        # table |<.34.shopping_list/blah blah|
        # table |shopping_list|
        #puts "TABLE:#{$~.to_a.inspect}"
        eat $&
        style, id, attribute, title_opts, title = $1, $2, $3, $4, $5
        id = id[0..-2] if id != ''
        if @translate_ids
          if @translate_ids != :zip
            node = find_node_by_pseudo(id)
            id = node.pseudo_id(@context[:node], @translate_ids) if node
          end
          store "|#{style}#{id == '' ? '' : "#{id}."}#{attribute}#{title}|"
        else
          node = id == '' ? @context[:node] : find_node_by_pseudo(id)
          store @helper.make_table(:style=>style, :node=>node, :attribute=>attribute, :title=>title)
        end
      elsif @text =~ /\A\|([<=>]\.|)(#{PSEUDO_ID_REGEXP})\.([a-zA-Z_]+)(\/([^\|]*)|)\|/m
        # table |<.:art++.shopping_list/blah blah|
        # table |shopping_list|
        #puts "TABLE SHORTCUT:#{$~.to_a.inspect}"
        eat $&
        text = $&
        style, id, attribute, title_opts, title = $1, $2, $3, $4, $5
        if node = find_node_by_pseudo(id)
          if @translate_ids
            # replace shortcut
            store "|#{style}#{node.pseudo_id(@context[:node], @translate_ids || :zip)}.#{attribute}#{title}|"
          else
            # write table
            store @helper.make_table(:style=>style, :node=>node, :attribute=>attribute, :title=>title)
          end
        elsif @translate_ids
          # node not found, ignore
          store text
        else
          # node not found
          store "[#{id} not found]"
        end
      else
        #puts "EAT:[#{$&}]"
        # eat marker and continue scan
        flush @text[0..0]
      end
    end
    
    def extract_code(fulltext)
      @escaped_code = []
      block_counter = -1
      fulltext.gsub!( /<code([^>]*)>(.*?)<\/code>/m ) do
        if @translate_ids
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
        if @translate_ids
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
        if @translate_ids
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
    
    def find_node_by_pseudo(id, base_node = @context[:node])
      secure(Node) { Node.find_node_by_pseudo(id, base_node) }
    end
    
    def parse_document_ids(str)
      meth = @translate_ids || :zip
      str.split(',').map do |id|
        if id.strip =~ /\A(\d+|#{PSEUDO_ID_REGEXP})/
          if node = find_node_by_pseudo($1)
            # replace shortcut
            node.pseudo_id(@context[:node], meth)
          else
            id  # keep
          end
        else
          id
        end
      end.compact
    end
  end
end