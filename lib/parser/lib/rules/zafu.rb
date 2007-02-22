require File.join(File.dirname(__FILE__) , 'zena')

module Zafu
  module Tags
    
    def render(context={})
      @zafu_tag_done = false
      res = render_zafu_tag(super)
    end
    
    def inspect
      @zafu_tag_done = false
      res = super
      if @zafu_tag && !@zafu_tag_done
        if res =~ /\A\[(\w+)(.*)\/\]\Z/
          res = "[#{$1}#{$2}]<#{tag}/>[/#{$1}]"
        elsif res =~ /\A\[([^\]]+)\](.*)\[\/(\w+)\]\Z/
          res = "[#{$1}]#{render_zafu_tag($2)}[/#{$3}]"
        end
        @zafu_tag_done = true
      end
      res
    end
    
    def params_to_html(params)
      para = []
      params.each do |k,v|
        para << " #{k}=#{params[k].inspect.gsub("'","TMPQUOTE").gsub('"',"'").gsub("TMPQUOTE",'"')}"
      end
      para.sort.join('')
    end
    
    def render_zafu_tag(text)
      return text unless (@zafu_tag && !@zafu_tag_done)
      res = "<#{@zafu_tag}#{params_to_html(@zafu_tag_params)}>#{text}</#{@zafu_tag}>"
      @zafu_tag_done = true
      res
    end
    
    def r_rename_asset
      return expand_with unless @tag
      tag = @params[:tag]
      unless @params[:src][0..0] == '/'
        case @tag
        when 'link'
          if @params[:rel].downcase == 'stylesheet'
            @params[:src] = @options[:helper].send(:template_url_for_asset, :stylesheet , @params[:src])
          else
            @params[:src] = @options[:helper].send(:template_url_for_asset, :link, @params[:src])
          end
        else
          @params[:src] = @options[:helper].send(:template_url_for_asset, @tag.to_sym , @params[:src])
        end
      end
      res   = "<#{@tag}#{params_to_html(@params)}"
      inner = expand_with
      if inner == ''
        res + "/>"
      else
        res + ">#{inner}"
      end
    end
  end
end

module Zafu
  module Rules
    def start(mode)
      if @zafu_tag = @options[:zafu_tag]
        @options.delete(:zafu_tag)
        @zafu_tag_params = @options[:zafu_tag_params] || {}
        @options.delete(:zafu_tag_params)
        @zafu_tag_count = 1
      elsif @zafu_tag = @options[:eat_zafu]
        @eat_zafu = true
        @options.delete(:eat_zafu)
        @zafu_tag_count = 1
      else
        @zafu_tag_count = 0
      end
      if @method == 'include'
        include_template
      elsif @options[:do]
        opts = {:method=>@options[:do]}
        
        # the matching zafu tag will be parsed by the last 'do', we must inform it to halt properly :
        opts[:eat_zafu] = @zafu_tag if @zafu_tag
        
        all_params = @options[:do_params]
        if all_params =~ /\A([^>]*?)do\s*=('|")([^\2]*?[^\\])\2([^>]*)\Z/
          # we have a sub 'do'
          match = $~
          opts[:do] = $3
          opts[:do_params] = $4
          opts[:params] = parse_params($1)
        else
          @options.delete(:do_params)
          @options.delete(:do)
          opts[:params] = parse_params(all_params)
        end
        make(:void, opts)
      else
        if mode == :tag
          scan_tag
        else
          enter(mode)
        end
      end
      if @eat_zafu
        @zafu_tag = nil
      end
    end
    
    def before_parse(text)
      text.gsub('<%', '&lt;%').gsub('%>', '%&gt;')
    end
  
    # scan rules
    def scan
      # puts "SCAN(#{@method}): [#{@text}]"
      if @text =~ /\A([^<]*)</
        flush $1
        if @text[1..1] == '/'
          scan_close_tag
        elsif @text[0..3] == '<!--'
          scan_html_comment
        else
          scan_tag
        end
      else
        # no more tags
        flush
      end
    end
  
    def scan_close_tag
      if @text =~ /\A<\/(z:|)([^>]+)>/
        # puts "CLOSE:[#{$&}]}" # ztag
        # closing tag
        if $1 == ''
          # /html
          if $2 == @zafu_tag
            # zafu tag
            @zafu_tag_count -= 1
            if @zafu_tag_count == 0
              eat $&
              leave
            else
              # keep the tag (false alert)
              flush $&
            end
          else
            # other html tag closing
            flush $&
          end
        else
          # /ztag
          eat $&
          if $2 != @method
            # error bad closing ztag
            store "<span class='zafu_error'>#{$&.gsub('<', '&lt;').gsub('>','&gt;')}</span>"
          end
          leave
        end
      else
        # error
        flush
      end
    end

    def scan_html_comment
      if @text =~ /<!--\|(.*?)-->/m
        # zafu html escaped
        eat $&
        @text = $1 + @text
      elsif @text =~ /<!--.*?-->/m
        # html comment
        flush $&
      else
        # error
        flush
      end
    end
  
    def scan_tag
      # puts "TAG(#{@method}): [#{@text}]"
      if @text =~ /\A<z:(\w+)([^>]*?)(\/?)>/
        # puts "ZTAG:[#{$&}]}" # ztag
        closed = ($3 != '')
        eat $&
        all_params = $2
        opts = {:method=>$1}
        if all_params =~ /\A([^>]*?)do\s*=('|")([^\2]*?[^\\])\2([^>]*)\Z/
          # we have a 'do'
          match = $~
          opts[:do] = $3
          opts[:do_params] = $4
          opts[:params] = parse_params($1)
        else
          opts[:params] = parse_params(all_params)
        end
        if closed
          make(:void, opts.merge(:text=>''))
        else  
          make(:void, opts)
        end
      elsif @text =~ /\A<(\w+)([^>]*?)zafu\s*=('|")([^\3]*?[^\\])\3([^>]*?)(\/?)>/
        # puts "ZAFU:[#{$&}]}" # zafu param tag
        eat $&
        match = $~
        all_params = match[5]
        closed = (match[6] != '')
        opts = {:method=>match[4], :zafu_tag=>match[1], :zafu_tag_params=>parse_params(match[2])}
        if all_params =~ /\A([^>]*?)do\s*=('|")([^\2]*?[^\\])\2([^>]*)\Z/
          # we have a 'do'
          match = $~
          opts[:do] = $3
          opts[:do_params] = $4
          opts[:params] = parse_params($1)
        else
          opts[:params] = parse_params(all_params)
        end
        if closed
          make(:void, opts.merge(:text=>''))
        else  
          make(:void, opts)
        end
      elsif @zafu_tag && @text =~ /\A<#{@zafu_tag}([^>]*?)(\/?)>/
        # puts "SAME:[#{$&}]}" # simple html tag same as zafu_tag
        flush $&
        @zafu_tag_count += 1 unless $2 == '/' # count opened zafu tags to be closed before return
      elsif @text =~ /\A<(link|img|script).*src\s*=/
        # puts "HTML:[#{$&}]}" # html
        make(:asset)
      elsif @text =~ /\A[^>]*?>/
        # html tag
        flush $&
      else
        # never closed tag
        flush
      end
    end
    
    def scan_asset
      # puts "ASSET(#{object_id}) [#{@text}]"
      if @text =~ /\A<(\w*)([^>]*?)(\/?)>/
        matched = $&
        eat $&
        @method = 'rename_asset'
        @tag = $1
        closed = ($3 != '')
        @params = parse_params($2)
        if closed
          leave(:asset)
        else
          enter(:inside_asset)
        end
      else
        # error
        @method = 'void'
        flush
      end
    end
    
    def scan_inside_asset
      if @text =~ /\A(.*?)<\/#{@params[:tag]}>/
        flush $&
        leave(:asset)
      else
        # never ending asset
        flush
      end
    end
  end
end