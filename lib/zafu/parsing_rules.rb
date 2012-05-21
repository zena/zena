require 'zafu/markup'

module Zafu
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
        # FIXME: make a better parser so that we do not have to worry with '>' at all.
        @markup.params = html_params.gsub('&gt;', '>')
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
      @end_tag_count  = 1

      # code indentation
      @markup.space_before = @options.delete(:space_before) # @space_before

      if @params =~ /\A([^>]*?)do\s*=('|")([^\2]*?[^\\])\2([^>]*)\Z/
        #puts $~.to_a.inspect
        # we have a sub 'do'
        params = $1
        sub_params = $4
        sub_method = $3.gsub("\\#{$2}", $2)

        @params = Markup.parse_params(params)

        # We need this flag to detect cases cases like <r:with part='list' do='other list finder'/>
        @sub_do = true

        opts = {:method => sub_method, :params => sub_params}

        # the matching zafu tag will be parsed by the last 'do', we must inform it to halt properly :
        opts[:end_tag] = @end_tag

        sub = make(:void, opts)
        @markup.space_after = sub.markup.space_after
        sub.markup.space_after = ""
      else
        @params = Markup.parse_params(@params)
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
      # puts "SCAN(#{@method}): [#{@text}]"
      if @text =~ %r{\A([^<]*?)(\s*)//!}m
        # comment
        flush $1
        eat $2
        scan_comment
      elsif @text =~ /\A([^<]*?)(^ *|)</m
        flush $1
        eat $2
        if @text[1..1] == '/'
          store $2
          scan_close_tag
        elsif @text[0..3] == '<!--'
          scan_html_comment(:space_before=> $2)
        elsif @text[0..8] == '<![CDATA['
          flush '<![CDATA['
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
        eat $&
        @text = opts[:space_before] + $1 + @text
      elsif @text =~ /\A<!--.*?-->/m
        # html comment
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

    def scan_tag(opts={})
      #puts "TAG(#{@method}): [#{@text}]"
      if @text =~ /\A<r:([\w_]+\??)([^>]*?)(\/?)>/
        #puts "RTAG:#{$~.to_a.inspect}" # ztag
        eat $&
        opts.merge!(:method=>$1, :params=>$2)
        opts.merge!(:text=>'') if $3 != ''
        make(:void, opts)
      #elsif @text =~ /\A<(\w+)([^>]*?)do\s*=('([^>]*?[^\\]|)'|"([^>]*?[^\\]|)")([^>]*?)(\/?)>/
      elsif @text =~ /\A<(\w+)([^>]*?)do\s*=('|")([^\3]*?[^\\]|)\3([^>]*?)(\/?)>/
        #puts "DO:#{$~.to_a.inspect}" # do tag
        eat $&
        reg = $~
        opts.merge!(:method=> reg[4].gsub("\\#{reg[3]}", reg[3]), :html_tag=>reg[1], :html_tag_params=>reg[2], :params=>reg[5])
        opts.merge!(:text=>'') if reg[6] != ''
        make(:void, opts)
      elsif @text =~ /\A<(\w+)(([^>]*?)\#\{([^>]*?))(\/?)>/
        # html tag with dynamic params
        #puts "OTHER_DYN:[#{$&}]"

        eat $&
        opts.merge!(:method => 'void', :html_tag => $1, :html_tag_params => $2, :params => {})
        opts.merge!(:text=>'') if $5 != ''
        make(:void, opts)
      elsif @text =~ /\A<(\w+)([^>]*?)id\s*=('[^>]*?[^\\]'|"[^>]*?[^\\]")([^>]*?)(\/?)>/
        #puts "ID:#{$~.to_a.inspect}" # id tag
        eat $&
        opts.merge!(:method=>'void', :html_tag=>$1, :params=>{:id => $3[1..-2]}, :html_tag_params=>"#{$2}id=#{$3}#{$4}")
        opts.merge!(:text=>'') if $5 != ''
        make(:void, opts)
      elsif @end_tag && @text =~ /\A<#{@end_tag.gsub('?', '\\?')}([^>]*?)(\/?)>/
        #puts "SAME:#{$~.to_a.inspect}" # simple html tag same as end_tag
        flush $&
        @end_tag_count += 1 unless $2 == '/'
      elsif @text =~ /\A<(link|img|script)/
        #puts "HTML:[#{$&}]" # html
        make(:asset)
      elsif @text =~ /\A<style>/
        flush $&
        make(:style)
      elsif @text =~ /\A[^>]*?>/
        # html tag
        #puts "OTHER:[#{$&}]"
        store opts[:space_before]
        flush $&
      else
        # never closed tag
        flush
      end
    end

    def scan_asset
      # puts "ASSET(#{object_id}) [#{@text}]"
      if @text =~ /\A<(\w+)([^>]*?)(\/?)>/
        eat $&
        @method = 'rename_asset'
        @markup.tag = $1
        @end_tag = $1
        closed = ($3 != '')
        @params = Markup.parse_params($2)
        if closed
          leave(:asset)
        elsif @markup.tag == 'script'
          enter(:void)
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
      if @text =~ /\A(.*?)<\/#{@end_tag.gsub('?', '\\?')}>/m
        eat $&
        store $1
        leave(:asset)
      else
        # never ending asset
        flush
      end
    end

    def scan_style
      if @text =~ /\A(.*?)<\/style>/m
        flush $&
        @method = 'rename_asset'
        @markup.tag = 'style'
        leave(:style)
      else
        # error
        @method = 'void'
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