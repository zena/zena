require 'zafu/markup'

module Zafu
  PARAM_KEY_REGEXP = %r{^ +([\w_\-\[\]:]+)=}
  PARAM_VALUE_REGEXP = %r{('|")(|[^\1]*?[^\\])\1}
  module ParsingRules
    # The context informs the rendering element about the current Node, node class, existing ids, etc. The
    # context is inherited by sub-elements.
    attr_reader :context

    # The helper is used to connect the compiler to the world of the application (read/write templates, access traductions, etc)
    attr_reader :helper

    # The markup (of class Markup) holds information on the tag (<li>), tag attributes (.. class='foo') and
    # indentation information that should be used when rendered. This context is not inherited.
    attr_accessor :markup

    # We need this flag to detect cases like <r:with part='list' do='other list finder'/>
    attr_reader :sub_do

    def self.included(base)
      base.before_parse :remove_erb
      base.before_process :unescape_ruby
    end

    # This callback is run just after the block is initialized (Parser#initialize).
    def start(mode)
      # tag_context
      @markup = Markup.new(@options.delete(:html_tag))

      # html_tag
      if html_params = @options.delete(:html_tag_params)
        @markup.params = html_params
      end

      # end_tag is used to know when to close parsing in sub-do
      # Example:
      # <li do='each' do='images'>
      #   <ul>
      #     <li><r:link/></li> <!-- do not close outer LI now: @end_tag_count != 0 -->
      #   </ul>
      # </li> <!-- close outer LI now: @end_tag_count == 0 -->
      #
      @end_tag = @markup.tag || @options.delete(:end_tag) || "r:#{@method}"
      @end_tag_count = 1

      # code indentation
      @markup.space_before = @options.delete(:space_before)

      if sub = @params.delete(:do)
        # we have a sub 'do'
        sub_method = sub.delete(:method)

        # We need this flag to detect cases cases like <r:with part='list' do='other list finder'/>
        @sub_do = true

        opts = {:method => sub_method, :params => sub}

        # the matching zafu tag will be parsed by the last 'do', we must inform it to halt properly :
        opts[:end_tag] = @end_tag

        sub = make(:void, opts)
        @markup.space_after = sub.markup.space_after
        sub.markup.space_after = ""
      end

      # set name used for include/replace from html_tag if not already set by superclass
      @name = extract_name

      if !@markup.tag && (@markup.tag = @params.delete(:tag))
        # Extract html tag parameters from @params
        @markup.steal_html_params_from(@params)
      end

      if @method == 'include' && @params[:template]
        include_template
      elsif mode == :tag && !sub
        scan_tag
      elsif !sub
        enter(mode)
      end
    end

    # Used to debug parser.
    def to_s
      "[#{@method}#{@name.blank? ? '' : " '#{@name}'"}#{@params.empty? ? '' : " #{@params.map{|k,v| ":#{k}=>#{v.inspect}"}.join(', ')}"}]" + (@blocks||[]).join('') + "[/#{@method}]"
    end

    def extract_name
      @options[:name] ||
      (%w{input select textarea}.include?(@method) ? nil : @params[:name]) ||
      @markup.params[:id] ||
      @params[:id]
    end

    def remove_erb(text)
      text.gsub('<%', '&lt;%').gsub('%>', '%&gt;').gsub(/<\Z/, '&lt;')
    end

    def unescape_ruby
      @params.each do |k,v|
        v.gsub!('&gt;', '>')
        v.gsub!('&lt;', '<')
      end
      @method.gsub!('&gt;', '>')
      @method.gsub!('&lt;', '<')
    end

    def single_child_method
      return @single_child_method if defined?(@single_child_method)
      @single_child_method = if @blocks.size == 1
        single_child = @blocks[0]
        return nil if single_child.kind_of?(String)
        single_child.markup.tag ? nil : single_child.method
      else
        nil
      end
    end

    # scan rules
    def scan
      #puts "SCAN(#{@method}): [#{@text[0..20]}]"
      if @text =~ %r{\A([^<]*?)(\s*)//!}m
        # comment
        flush $1
        eat $2
        scan_comment
      elsif @text =~ /\A([^<]*)</m
        found = $1
        if found =~ /^ *$/
          eat found
          space = found
        else
          flush found
          space = ''
        end
        
        if @text[1..1] == '/'
          store space
          scan_close_tag
        elsif %w{! ?}.include?(@text[1..1])
          if @text[2..3] == '--'
            store space
            scan_html_comment
          elsif @text =~ /\A\s*<([^>]+)>/m
            # Doctype/xml
            flush $&
          end
        elsif @text[0..8] == '<![CDATA['
          store space
          flush '<![CDATA['
        elsif found.last == ' ' && @text[0..1] == '< '
          # solitary ' < '
          store space
          flush '< '
          scan
        else
          scan_tag(:space_before => space)
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

            @markup.space_after = $2
            leave
          else
            # keep the tag (false alert)
            flush $&
          end
        elsif $1[0..1] == 'r:'
          # /rtag
          eat $&
          if $1 != @end_tag
            # error bad closing rtag
            store "<span class='parser_error'>#{$&.gsub('<', '&lt;').gsub('>','&gt;')} should be &lt;/#{@end_tag}&gt;</span>"
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
      if @text =~ /\A<!--\|(.*?)-->/m
        # zafu html escaped
        #puts "ZAFU_HTML_ESCAPED[#{$&}]"
        eat $&
        @text = opts[:space_before] + $1 + @text
      elsif @text =~ /\A<!--.*?-->/m
        # html comment
        #puts "HTML_COMMENT[#{$&}]"
        flush $&
      else
        # error
        flush
      end
    end

    def scan_comment
      if @text =~ %r{\A//!.*(\n|\Z)}
        # zafu html escaped
        eat $&
      else
        # error
        flush
      end
    end
    
    def get_params
      params = Zafu::OrderedHash.new
      raw = ''
      while @text =~ PARAM_KEY_REGEXP
        raw << $&
        eat $&
        key = $1
        
        if @text =~ PARAM_VALUE_REGEXP
          raw_t = $&
          quote = $1
          eat $&
          value = $2.gsub("\\#{quote}", quote)
          if key == 'do'
            # Sub do
            sub, raw = get_params
            sub[:method] = value
            params[:do] = sub
            return params
          else
            raw << raw_t
            params[key.to_sym] = value
          end
        end
      end
      return params, raw
    end

    def scan_tag(opts={})
      #puts "TAG(#{@method}): [#{@text[0..20]}]"
      # FIXME: Better parameters parsing could avoid the &gt; hack. Create a "scan_params" method.
      if @text =~ /\A<r:([\w_]+\??)/
        #puts "RTAG:#{$~.to_a.inspect}" # ztag
        method = $1
        eat $&
        params, raw = get_params

        if @text =~ /\A(\/?)>/
          eat $&
          opts.merge!(:method=>method, :params=>params)
          opts.merge!(:text=>'') if $1 != ''
          make(:void, opts)
        else
          # ERROR
          flush
        end
      #elsif @text =~ /\A<(\w+)([^>]*?)do\s*=('([^>]*?[^\\]|)'|"([^>]*?[^\\]|)")([^>]*?)(\/?)>/
      elsif @text =~ /\A<([\w:]+)/
        html_tag = $1
        eat $&
        params, raw = get_params

        #puts "HTML(#{html_tag}):[#{@text}]" # html tag
        if @text =~ /\A\s*(\/?)>/
          eat $&
          is_end_tag = !$1.blank?

          if sub = params.delete(:do)
            # puts "SUB_DO:#{params.inspect}"
            # do tag
            method = sub.delete(:method)
            opts.merge!(:text=>'') if is_end_tag
            opts.merge!(
            :html_tag => html_tag,
            :html_tag_params => params,
            :method => method,
            :params => sub
            )
            make(:void, opts)
          elsif raw =~ /\#\{/ || params[:id]
            # puts "HTML_DYN|ID:#{@params.inspect}"
            # If we have an :id, we need to store this as a block in case it is replaced
            # html tag with dynamic params
            opts.merge!(:text=>'') if is_end_tag
            opts.merge!(:method => 'void', :html_tag => html_tag, :html_tag_params => params)
            make(:void, opts)
          elsif @end_tag && html_tag == @end_tag
            #puts "PLAIN(END):#{@params.inspect}"
            # plain html tag
            store "#{opts[:space_before]}<#{html_tag}#{raw}#{is_end_tag ? '/' : ''}>"
            @end_tag_count += 1 unless is_end_tag
          elsif %w{link img script}.include?(html_tag)    
            #puts "ASSET: [#{@text}]"
            opts.merge!(:text=>'') if is_end_tag
            opts.merge!(:method => 'rename_asset', :html_tag_params => params, :params => params, :html_tag => html_tag)
            make(:asset, opts)
          else
            #puts "PLAIN:<#{html_tag}#{raw}#{is_end_tag ? '/' : ''}>"
            # plain html tag
            store "#{opts[:space_before]}<#{html_tag}#{raw}#{is_end_tag ? '/' : ''}>"
          end
        else
          # ERROR
          flush
        end
      else
        # unknown tag type
        store %Q{<span class='parser_error'>Invalid tag near '#{@text[0..10].gsub('>','&gt;').gsub('<','&lt;')}'</span>}
        @text = ''
      end
    end

    def scan_asset
      @end_tag = @markup.tag
      if @markup.tag == 'script'
        enter(:void)
      else
        enter(:inside_asset)
      end
    end

    def scan_inside_asset
      if @text =~ /\A(.*?)<\/#{@end_tag.gsub('?', '\\?')}>/m
        eat $&
        store $1
        leave(:asset)
      else
        # never ending asset
        flush
      end
    end

    # Helper during compilation to make a block
    def add_block(text_or_opts, at_start = false)
      # avoid wrapping objects in [void][/void]
      bak = @blocks
        @blocks = []
        if text_or_opts.kind_of?(String)
          new_blocks = make(:void, :method => 'void', :text => text_or_opts).blocks
        else
          new_blocks = [make(:void, text_or_opts)]
        end
        if at_start
          bak = new_blocks + bak
        else
          bak += new_blocks
        end
      @blocks = bak
      # Force descendants rebuild
      @all_descendants = nil
    end

    # Helper during compilation to wrap current content in a new block
    def wrap_in_block(text_or_opts)
      # avoid wrapping objects in [void][/void]
      bak = @blocks
      @blocks = []
      if text_or_opts.kind_of?(String)
        wrapper = make(:void, :method => 'void', :text => text_or_opts)
      else
        wrapper = make(:void, text_or_opts)
      end
      wrapper.blocks = bak
      @blocks = [wrapper]
      # Force descendants rebuild
      @all_descendants = nil
    end
  end # ParsingRules
end # Zafu