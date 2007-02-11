module ParserRules
  module Zafu
    # scan rules
    def scan
      # puts "SCAN(#{@method}): [#{@text}]"
      if @text =~ /\A([^<]*)</
        flush $1
        enter(:tag)
      else
        # no more tags
        flush
      end
    end
    
    def scan_tag
      zafu_tag_count = 1
      # puts "TAG(#{@method}): [#{@text}]"
      if @text =~ /\A<\/(z:|)([^>]+)>/
        # puts "CLOSE:[#{$&}]}" # ztag
        # closing tag
        if $1 == ''
          # /html
          flush $&
          if $2 == @options[:zafu_tag]
            zafu_tag_count -= 1
            quit if zafu_tag_count == 0
          end
        else
          # /ztag
          eat $&
          if $2 == @method
            quit
          else
            # error bad closing ztag
            out "<span class='zafu_error'>#{$2.gsub('<', '&lt;').gsub('>','&gt;')}</span>"
          end
          quit
        end
      elsif @text =~ /\A<z:(\w+)([^>]*?)(\/?)>/
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
        out "<#{zafu_tag}"
        [:class, :id].each do |key|
          if params[key]
            out " #{key}=#{params[key].inspect.gsub("'","TMPQUOTE").gsub('"',"'").gsub("TMPQUOTE",'"')}"
            params.delete(key)
          end
        end
        out ">"
        if closed
          make(:void, :zafu_tag=>zafu_tag, :params=>params, :method=>method, :text=>'')
          out "</#{zafu_tag}>"
        else
          make(:void, :zafu_tag=>zafu_tag, :params=>params, :method=>method)
          zafu_tag_count += 1 if zafu_tag == @zafu_tag # same zafu_tag as the one we are currently in
        end
      elsif @options[:zafu_tag] && @text =~ /\A<#{@options[:zafu_tag]}([^>]*?)(\/?)>/
        # puts "SAME:[#{$&}]}" # simple html tag same as zafu_tag
        flush $&
        zafu_tag_count += 1 unless $2 == '/' # count opened zafu tags to be closed before return
      elsif @text =~ /\A<(link|img|script)([^>]*?)(\/?)>/
        # puts "HTML:[#{$&}]}" # html
        matched   = $&
        eat matched
        method    = $1
        end_slash = $3
        params = parse_params($2)
        if params[:src] && params[:src][0..0] != '/'
          case method
          when 'link'
            if params[:rel].downcase == 'stylesheet'
              params[:src] = @options[:helper].template_url_for_asset(:stylesheet,params[:src])
            else
              params[:src] = @options[:helper].template_url_for_asset(:link, params[:src])
            end
          else
            params[:src] = @options[:helper].template_url_for_asset(method.to_sym , params[:src])
          end
          out "<#{method}"
          params.each do |k,v|
            out " #{k}=#{v.inspect.gsub("'","TMPQUOTE").gsub('"',"'").gsub("TMPQUOTE",'"')}"
          end
          out "#{end_slash}>"
        else
          out matched
        end
      elsif @text =~ /\A[^>]*>/
        # html tag
        flush $&
      else
        # never closed tag
        flush
      end
    end
    
    # render rules
    def r_hello
      "hello world!"
    end
  end
end