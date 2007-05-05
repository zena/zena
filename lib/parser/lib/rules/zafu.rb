require File.join(File.dirname(__FILE__) , 'zena')

module Zafu
  module Tags
    attr_accessor :html_tag, :html_tag_params
    
    def replace_with(obj)
      super
      @html_tag          = obj.html_tag        || @html_tag
      @html_tag_params   = (obj.html_tag_params.empty? && !@html_tag_params.empty?) ? @html_tag_params : obj.html_tag_params
    end
    
    def empty?
      super && @html_tag_params == {} && @html_tag.nil?
    end
    
    def before_render
      return unless super
      @html_tag_done = false
      unless @html_tag
        if @params[:id] || @params[:class]
          @html_tag = @params[:tag] || 'div'
          @params.delete(:tag)
          @html_tag_params = {}
          [:id, :class].each do |k|
            @html_tag_params[k] = @params[k] if @params[k]
            @params.delete(k)
          end
        end
      end
      true
    end
    
    def after_render(text)
      render_html_tag(super)
    end
    
    def inspect
      @html_tag_done = false
      res = super
      if @html_tag && !@html_tag_done
        if res =~ /\A\[(\w+)(.*)\/\]\Z/
          res = "[#{$1}#{$2}]<#{@html_tag}/>[/#{$1}]"
        elsif res =~ /\A\[([^\]]+)\](.*)\[\/(\w+)\]\Z/
          res = "[#{$1}]#{render_html_tag($2)}[/#{$3}]"
        end
        @html_tag_done = true
      end
      res
    end
    
    def params_to_html(params)
      para = []
      params.each do |k,v|
        if v.kind_of?(Array)
          # Array is used to indicate that the code is already escaped.
          para << " #{k}=#{v}"
        else
          para << " #{k}='#{v}'" # .gsub("'","\\'")}
        end
      end
      # puts para.inspect
      para.sort.join('')
    end
    
    def render_html_tag(text)
      return text if @html_tag_done
      if @html_tag
        res = "<#{@html_tag}#{params_to_html(@html_tag_params || {})}>#{text}</#{@html_tag}>"
      else
        res = text
      end
      @html_tag_done = true
      (@space_before || '') + res + (@space_after || '')
    end
    
    def r_rename_asset
      return expand_with unless @html_tag
      opts = {}
      case @html_tag
      when 'link'
        key = :href
        if @params[:rel].downcase == 'stylesheet'
          opts[:type] = :stylesheet
        else
          opts[:type] = :link
        end
      else
        key = :src
        opts[:type] = @html_tag.to_sym
      end
      
      opts[:src] = @params[key]
      if opts[:src] && opts[:src][0..0] != '/'
        opts[:current_folder] = @options[:current_folder]
        @params[key] = @options[:helper].send(:template_url_for_asset, opts)
      end
      
      res   = "<#{@html_tag}#{params_to_html(@params)}"
      @html_tag_done = true
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
      # html_tag
      @html_tag = @options[:html_tag]
      @options.delete(:html_tag)
      @html_tag_params = parse_params(@options[:html_tag_params])
      @options.delete(:html_tag_params)
      
      # end_tag
      @end_tag = @html_tag || @options[:end_do] || "z:#{@method}"
      @end_tag_count  = 1
      
      # code indentation
      @space_before = @options[:space_before]
      @options.delete(:space_before)
      
      # puts "[#{@space_before}(#{@method})#{@space_after}]"
      if @params =~ /\A([^>]*?)do\s*=('|")([^\2]*?[^\\])\2([^>]*)\Z/  
        # we have a sub 'do'
        @params = parse_params($1)
        opts = {:method=>$3, :params=>$4}
        
        # the matching zafu tag will be parsed by the last 'do', we must inform it to halt properly :
        opts[:end_do] = @end_tag
        
        sub = make(:void, opts)
        @space_after = sub.instance_variable_get(:@space_after)
        sub.instance_variable_set(:@space_after,"")
        if @method == 'include'
          include_template
        end
      else  
        @params = parse_params(@params)
        if @method == 'include'
          include_template
        elsif mode == :tag
          scan_tag
        else
          enter(mode)
        end
      end
      if !@html_tag && (@html_tag = @params[:tag])
        @params.delete(:tag)
        # get html tag parameters from @params
        @html_tag_params = {}
        [:class, :id].each do |k|
          next unless @params[k]
          @html_tag_params[k] = @params[k]
          @params.delete(k)
        end
      end
    end
    
    def before_parse(text)
      text.gsub('<%', '&lt;%').gsub('%>', '%&gt;')
    end
  
    # scan rules
    def scan
      # puts "SCAN(#{@method}): [#{@text}]"
      if @text =~ /\A([^<]*?)(^ *|)</m
        flush $1
        eat $2
        if @text[1..1] == '/'
          store $2
          scan_close_tag
        elsif @text[0..3] == '<!--'
          scan_html_comment(:space_before=> $2)
        else
          scan_tag(:space_before=> $2)
        end
      else
        # no more tags
        flush
      end
    end
  
    def scan_close_tag
      if @text =~ /\A<\/([^>]+)>( *\n+|)/m
        # puts "CLOSE:[#{$&}]}" # ztag
        # closing tag
        if $1 == @end_tag
          @end_tag_count -= 1
          if @end_tag_count == 0
            eat $&
            @space_after = $2
            leave
          else  
            # keep the tag (false alert)
            flush $&
          end
        elsif $1[0..1] == 'z:'
          # /ztag
          eat $&
          if $1 != @end_tag
            # error bad closing ztag
            store "<span class='parser_error'>#{$&.gsub('<', '&lt;').gsub('>','&gt;')}</span>"
          end
          leave
        else  
          # other html tag closing
          flush $&
        end
      else
        # error
        flush
      end
    end

    def scan_html_comment(opts={})
      if @text =~ /<!--\|(.*?)-->/m
        # zafu html escaped
        eat $&
        @text = opts[:space_before] + $1 + @text
      elsif @text =~ /<!--.*?-->/m
        # html comment
        flush $&
      else
        # error
        flush
      end
    end
  
    def scan_tag(opts={})
      # puts "TAG(#{@method}): [#{@text}]"
      if @text =~ /\A<z:([\w_]+)([^>]*?)(\/?)>/
        # puts "ZTAG:[#{$&}]}" # ztag
        eat $&
        opts.merge!(:method=>$1, :params=>$2)
        opts.merge!(:text=>'') if $3 != ''
        make(:void, opts)
      elsif @text =~ /\A<(\w+)([^>]*?)do\s*=('|")([^\3]*?[^\\])\3([^>]*?)(\/?)>/
        # puts "DO:[#{$&}]}" # do tag
        eat $&
        opts.merge!(:method=>$4, :html_tag=>$1, :html_tag_params=>$2, :params=>$5)
        opts.merge!(:text=>'') if $6 != ''
        make(:void, opts)
      elsif @end_tag && @text =~ /\A<#{@end_tag}([^>]*?)(\/?)>/
        # puts "SAME:[#{$&}]}" # simple html tag same as end_tag
        flush $&
        @end_tag_count += 1 unless $2 == '/'
      elsif @text =~ /\A<(link|img|script)/
        # puts "HTML:[#{$&}]}" # html
        make(:asset)
      elsif @text =~ /\A[^>]*?>/
        # html tag
        # puts "OTHER:[#{$&}]"
        store opts[:space_before]
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
        @html_tag = @end_tag = $1
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
      if @text =~ /\A(.*?)<\/#{@end_tag}>/m
        flush $&
        leave(:asset)
      else
        # never ending asset
        flush
      end
    end
  end
end