require File.join(File.dirname(__FILE__) , 'zena')

module ParserTags
  module Zafu
    def r_set
      copy = self.dup
      copy.method = 'void'
      @pass[@params[:var]] = copy
      ""
    end
    def r_get
      if block = @context[@params[:var]]
        new_context = @context.dup
        new_context.delete(@params[:var])
        res = block.render(new_context)
      else
        expand_with
      end
    end
    def r_inspect
      expand_with
      @blocks = []
      self.inspect
    end
    
    def r_include
      expand_with
      @blocks = @included_blocks
      expand_with(@insight)
    end
  end
end

module ParserRules
  module Zafu
    def start(mode)
      if @options[:zafu_tag]
        @zafu_tag_count = 1
      else
        @zafu_tag_count = 0
      end
      if @method == 'include'
        include_template
      else
        if mode == 'tag'
          scan_tag
        else
          enter(mode)
        end
      end
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
      elsif @text =~ /\A<(link|img|script)([^>]*?)(\/?)>/
        # puts "HTML:[#{$&}]}" # html
        matched   = $&
        eat $&
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
          store "<#{method}"
          res = []
          params.each do |k,v|
            res << "#{k}=#{v.inspect.gsub("'","TMPQUOTE").gsub('"',"'").gsub("TMPQUOTE",'"')}"
          end
          if res != []
            store " #{res.sort.join(' ')}#{end_slash}>"
          else
            store "#{end_slash}>"
          end
        else
          store matched
        end
      elsif @text =~ /\A[^>]*?>/
        # html tag
        flush $&
      else
        # never closed tag
        flush
      end
    end
  
    def include_template
      # fetch text
      text = @text
      @text, absolute_url = self.class.find_template_text(@params[:template], @options[:helper], @options[:current_folder])
      if absolute_url
        if @options[:included_history].include?(absolute_url)
          @text = "<span class='zafu_error'>[include error: #{(@options[:included_history] + [absolute_url]).join(' --&gt; ')} ]</span>"
        else
          @options[:included_history] += [absolute_url]
          @options[:current_folder] = absolute_url.split('/')[0..-2].join('/')
        end
      end
    
      enter(:void) # scan fetched text
      @included_blocks = @blocks
      
      @blocks = []
      @text = text
      enter(:void) # normal scan on content
    end
  end
end