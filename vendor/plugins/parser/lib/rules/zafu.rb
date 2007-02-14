require File.join(File.dirname(__FILE__) , 'zena')

module Zafu
  module Tags
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
      res = []
      @params.each do |k,v|
        res << "#{k}=#{v.inspect.gsub("'","TMPQUOTE").gsub('"',"'").gsub("TMPQUOTE",'"')}"
      end
      if res != []
        res = "<#{@tag} #{res.sort.join(' ')}"
      else
        res = "<#{@tag}"
      end
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
      if @options[:zafu_tag]
        @zafu_tag_count = 1
      else
        @zafu_tag_count = 0
      end
      if @method == 'include'
        include_template
      else
        if mode == :tag
          scan_tag
        else
          enter(mode)
        end
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
          if $2 == @options[:zafu_tag]
            # zafu tag
            @zafu_tag_count -= 1
            if @zafu_tag_count == 0
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
  
    def scan_tag
      # puts "TAG(#{@method}): [#{@text}]"
      if @text =~ /\A<z:(\w+)([^>]*?)(\/?)>/
        # puts "ZTAG:[#{$&}]}" # ztag
        method = $1
        closed = ($3 != '')
        eat $&
        params = parse_params($2)
        if closed
          make(:void, :params=>params, :method=>method, :text=>'')
        else          
          make(:void, :params=>params, :method=>method)
        end
      elsif @text =~ /\A<(\w+)([^>]*?)zafu\s*=([^>]*?)(\/?)>/
        # puts "ZAFU:[#{$&}]}" # zafu param tag
        eat $&
        zafu_tag = $1
        closed = ($4 != '')
        params = parse_params($2+"zafu="+$3)
        method = params[:zafu]
        params.delete(:zafu)
        store "<#{zafu_tag}"
        [:class, :id].each do |key|
          if params[key]
            store " #{key}=#{params[key].inspect.gsub("'","TMPQUOTE").gsub('"',"'").gsub("TMPQUOTE",'"')}"
            params.delete(key)
          end
        end
        store ">"
        if closed
          make(:void, :zafu_tag=>zafu_tag, :params=>params, :method=>method, :text=>'')
          store "</#{zafu_tag}>"
        else
          make(:void, :zafu_tag=>zafu_tag, :params=>params, :method=>method)
          @zafu_tag_count += 1 if zafu_tag == @options[:zafu_tag] # same zafu_tag as the one we are currently in
        end
      elsif @options[:zafu_tag] && @text =~ /\A<#{@options[:zafu_tag]}([^>]*?)(\/?)>/
        # puts "SAME:[#{$&}]}" # simple html tag same as zafu_tag
        flush $&
        @zafu_tag_count += 1 unless $2 == '/' # count opened zafu tags to be closed before return
      elsif @text =~ /\A<(link|img|script)/
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
        leave(:asset) 
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