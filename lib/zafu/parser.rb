module Zafu

  def self.parser_with_rules(*modules)
    parser = Class.new(Parser)
    modules.flatten.each do |mod|
      parser.send(:include, mod)
    end
    parser
  end

  class Parser
    # If you wonder what the difference is between 'after_wrap' and 'after_process' here it is:
    # 'after_wrap' is called by the 'wrap' method from within the method handler, 'after_process' is called
    # at the very end. Example:
    #
    #   <% if var = Node.all %>                                  | <---
    #     <li>...</li>              <--- content for after_wrap  | <---  content for after_process
    #   <% end %>                                                | <---
    #


    TEXT_CALLBACKS    = %w{before_parse after_parse before_wrap wrap after_wrap after_process}
    PROCESS_CALLBACKS = %w{before_process expander process_unknown}
    CALLBACKS         = TEXT_CALLBACKS + PROCESS_CALLBACKS

    @@callbacks = {}
    attr_accessor :text, :name, :method, :pass, :options, :blocks, :ids, :defined_ids, :parent, :errors

    # Method parameters "<r:show attr='name'/>" (params contains {'attr' => 'name'}).
    attr_accessor :params

    class << self
      def new_with_url(path, opts={})
        helper = opts[:helper] || Zafu::MockHelper.new
        text, fullpath, base_path = self.get_template_text(path, helper)
        return parser_error("template '#{path}' not found", 'include') unless text
        self.new(text, :helper => helper, :base_path => base_path, :included_history => [fullpath], :root => path, :master_template => opts[:master_template])
      end

      # Retrieve the template text in the current folder or as an absolute path.
      # This method is used when 'including' text
      def get_template_text(path, helper, base_path=nil, opts={})
        res = helper.send(:get_template_text, path, base_path, opts)
        return [parser_error("template '#{path}' not found", 'include'), nil, nil] unless res
        res
      end

      def parser_error(message, method)
        "<span class='parser_error'><span class='method'>#{erb_safe method}</span> <span class='message'>#{erb_safe message}</span></span>"
      end

      def erb_safe(text)
        text.gsub('<%', '&lt;%').gsub('%>', '%&gt;')
      end

      CALLBACKS.each do |clbk|
        eval %Q{
          attr_accessor :#{clbk}_callbacks

          def #{clbk}_callbacks
            @#{clbk}_callbacks ||= superclass.respond_to?(:#{clbk}_callbacks) ? superclass.#{clbk}_callbacks : []
          end

          def #{clbk}(*args)
            self.#{clbk}_callbacks += args
          end
        }
      end
    end # class << self

    PROCESS_CALLBACKS.each do |clbk|
      eval %Q{
        def #{clbk}
          self.class.#{clbk}_callbacks.each do |callback|
            send(callback)
          end
        end
      }
    end

    def expander
      self.class.expander_callbacks.reverse_each do |callback|
        if res = send(callback)
          if res.kind_of?(String)
            @result << res
          end
          return @result
        end
      end
      nil
    end

    TEXT_CALLBACKS.each do |clbk|
      eval %Q{
        def #{clbk}(text)
          self.class.#{clbk}_callbacks.each do |callback|
            text = send(callback, text)
          end
          text
        end
      }
    end

    alias wrap_callbacks wrap

    def wrap(text)
      after_wrap(
        wrap_callbacks(
          before_wrap(text) + @out_post
        )
        # @text contains unparsed data (white space)
      ) + @text
    end

    # This method is called at the very beginning of the processing chain and is
    # used to store state to make 'process' reintrant...
    def save_state
      {
       :@context  => @context, # <== we need this when rendering twice the same part
       :@result   => @result,
       :@out_post => @out_post,
       :@params   => @params.dup,
       :@method   => @method,
       :@var      => @var,
      }
    end

    # Restore state from a hash
    def restore_state(saved)
      saved.each do |key, value|
        instance_variable_set(key, value)
      end
    end

    def parser_error(message, method = @method, halt = true)
      if halt
        self.class.parser_error(message, method)
      else
        @errors << self.class.parser_error(message, method)
        nil
      end
    end

    def parser_continue(message, method = @method)
      parser_error(message, method, false)
    end

    def process_unknown
      self.class.process_unknown_callbacks.each do |callback|
        if res = send(callback)
          return res
        end
      end
      @errors.empty? ? default_unknown : show_errors
    end

    def show_errors
      @errors.join(' ')
    end

    def initialize(text, opts={})
      @stack   = []
      @ok      = true
      @blocks  = []
      @errors  = []

      @options = {:mode=>:void, :method=>'void'}.merge(opts)
      @params  = @options.delete(:params) || {}
      @method  = @options.delete(:method)
      @ids     = @options[:ids] ||= {}
      original_ids = @ids.dup
      @defined_ids = {} # ids defined in this node or this node's sub blocks
      mode     = @options.delete(:mode)
      @parent  = @options.delete(:parent)

      if opts[:sub]
        @text = text
      else
        @text = before_parse(text)
      end

      start(mode)

      # set name
      @name ||= extract_name
      @options[:ids][@name] = self if @name

      unless opts[:sub]
        @text = after_parse(@text)
      end

      @ids.keys.each do |k|
        if original_ids[k] != @ids[k]
          @defined_ids[k] = @ids[k]
        end
      end
      @ok
    end

    def extract_name
      @options[:name] || @params[:id]
    end

    def to_erb(context)
      context[:helper] ||= @options[:helper]
      process(context)
    end

    def start(mode)
      enter(mode)
    end

    # Pass some contextual information to siblings
    def pass(elems = nil)
      return @pass unless elems
      (@pass ||= {}).merge!(elems)
      @pass
    end

    # Hook called when replacing part of an included template with '<r:with part='main'>...</r:with>'
    # This replaces the current object 'self' which is in the original included template, with the custom version 'obj'.
    def replace_with(obj)
      # keep @method (obj's method is always 'with')
      @blocks = obj.blocks.empty? ? @blocks : obj.blocks
      obj.params.delete(:part)
      @params.merge!(obj.params)
    end

    # Hook called when including a part "<r:include template='layout' part='title'/>"
    def include_part(obj)
      [obj]
    end

    def empty?
      @blocks == [] && (@params == {} || @params == {:part => @params[:part]})
    end

    def process(context={})
      return '' if @method == 'ignore' || @method.blank?

      saved = save_state

      if @name
        # we pass the name as 'context' in the children tags
        @context = context.merge(:name => @name)
      else
        @context = context
      end
      # FIXME: replace with array and join (faster)
      @result   = ""
      @out_post = ""
      @pass     = nil

      before_process

      res = wrap(expander || default_expander)

      res = after_process(res)

      # restore state
      restore_state(saved)

      res
    end

    # Default processing
    def default_expander
      if respond_to?("r_#{@method}".to_sym)
        do_method("r_#{@method}".to_sym)
      else
        do_method(:process_unknown)
      end
    end

    def do_method(sym)
      res = self.send(sym)
      if res.kind_of?(String)
        @result << res
      elsif @result.blank?
        @result << (@errors.empty? ? '' : show_errors)
      end
      @result
    end

    def r_void
      expand_with
    end

    alias to_s r_void

    def r_inspect
      expand_with(:preflight=>true)
      @blocks = []
      self.inspect
    end

    # basic rule to display errors
    def default_unknown
      sp = ""
      @params.each do |k,v|
        sp += " #{k}=#{v.inspect.gsub("'","TMPQUOTE").gsub('"',"'").gsub("TMPQUOTE",'"')}"
      end

      res = "<span class='parser_unknown'>&lt;r:#{@method}#{sp}"
      inner = expand_with
      if inner != ''
        res + "&gt;</span>#{inner}<span class='parser_unknown'>&lt;r:/#{@method}&gt;</span>"
      else
        res + "/&gt;</span>"
      end
    end

    # Set context with variables (unsafe) from template.
    def r_expand_with
      hash = {}
      @params.each do |k,v|
        hash["exp_#{k}"] = v.inspect
      end
      expand_with(hash)
    end

    def r_ignore
      ''
    end

    def include_template
      return parser_error("missing 'template' attribute") unless @params[:template]
      if @options[:part] && @options[:part] == @params[:part]
        # fetching only a part, do not open this element (same as original caller) as it is useless and will make us loop the loop.
        @method = 'ignore'
        enter(:void)
        return
      end
      @method = 'void'

      # fetch text
      @options[:included_history] ||= []

      included_text, absolute_url, base_path = self.class.get_template_text(@params[:template], @options[:helper], @options[:base_path])

      if absolute_url
        absolute_url += "::#{@params[:part].gsub('/','_')}" if @params[:part]
        absolute_url += "??#{@options[:part].gsub('/','_')}" if @options[:part]
        if @options[:included_history].include?(absolute_url)
          included_text = parser_error("infinity loop: #{(@options[:included_history] + [absolute_url]).join(' --&gt; ')}", 'include')
        else
          included_history  = @options[:included_history] + [absolute_url]
        end
      else
        # Error: included_text contains the error meessage
        @blocks = [included_text]
        return
      end

      res = self.class.new(included_text, :helper => @options[:helper], :base_path => base_path, :included_history => included_history, :part => @params[:part], :parent => self) # we set :part to avoid loop failure when doing self inclusion

      if @params[:part]
        if iblock = res.ids[@params[:part]]
          included_blocks = include_part(iblock)
          # get all ids from inside the included part:
          @ids.merge! iblock.defined_ids
        else
          included_blocks = [parser_error("'#{@params[:part]}' not found in template '#{@params[:template]}'", 'include')]
        end
      else
        included_blocks = res.blocks
        @ids.merge! res.ids
      end

      enter(:void) # normal scan on content
      # replace 'with'

      @blocks.each do |b|
        next if b.kind_of?(String) || b.method != 'with'
        if target = res.ids[b.params[:part]]
          if target.kind_of?(String)
            # error
          elsif b.empty?
            target.method = 'ignore'
          else
            target.replace_with(b)
          end
        else
          # part not found
          parser_error("'#{b.params[:part]}' not found in template '#{@params[:template]}'", 'with')
        end
      end
      @blocks = included_blocks
    end

    # Return a hash of all descendants. Find a specific descendant with descendant['form'] for example.
    def all_descendants
      @all_descendants ||= begin
        d = {}
        @blocks.each do |b|
          next if b.kind_of?(String)
          b.public_descendants.each do |k,v|
            d[k] ||= []
            d[k]  += v
          end
          # latest is used first: use direct children before grandchildren.
          d[b.method] ||= []
          d[b.method] << b
        end
        d
      end
    end

    # Find a direct child with +child[method]+.
    def child
      Hash[*@blocks.map do |b|
        b.kind_of?(String) ? nil : [b.method, b]
      end.compact.flatten]
    end

    def dynamic_blocks?
      @blocks.detect { |b| !b.kind_of?(String) }
    end

    def descendants(key)
      all_descendants[key] || []
    end

    def ancestors
      @ancestors ||= begin
        if parent
          parent.ancestors + [parent]
        else
          []
        end
      end
    end

    alias public_descendants all_descendants

    # Return the last defined parent for the given keys.
    def ancestor(keys)
      keys = Array(keys)
      ancestors.reverse_each do |a|
        if keys.include?(a.method)
          return a
        end
      end
      nil
    end

    # Return the last defined descendant for the given key.
    def descendant(key)
      descendants(key).last
    end

    # Return the root block (the one opened first).
    def root
      @root ||= parent ? parent.root : self
    end

    def success?
      return @ok
    end

    def flush(str=@text)
      return if str == ''
      if @blocks.last.kind_of?(String)
        @blocks[-1] << str
      else
        @blocks << str
      end
      @text = @text[str.length..-1]
    end

    # Build blocks
    def store(obj)
      if obj.kind_of?(String) && @blocks.last.kind_of?(String)
        @blocks[-1] << obj
      elsif obj != ''
        @blocks << obj
      end
    end

    # Output ERB code during ast processing.
    def out(str)
      @result << str
      # Avoid double entry when this is the last call in a render method.
      true
    end

    # Output ERB code that will be inserted after @result.
    def out_post(str)
      @out_post << str
      # Avoid double entry when this is the last call in a render method.
      true
    end

    # Advance parser.
    def eat(arg)
      if arg.kind_of?(String)
        len = arg.length
      elsif arg.kind_of?(Fixnum)
        len = arg
      else
        raise
      end
      @text = @text[len..-1]
    end

    def enter(mode)
      @stack << mode
      # puts "ENTER(#{@method},:#{mode}) [#{@text}] #{@zafu_tag_count.inspect}"
      if mode == :void
        sym = :scan
      else
        sym = "scan_#{mode}".to_sym
      end
      while (@text != '' && @stack[-1] == mode)
        # puts "CONTINUE(#{@method},:#{mode}) [#{@text}] #{@zafu_tag_count.inspect}"
        self.send(sym)
      end
      # puts "LEAVE(#{@method},:#{mode}) [#{@text}] #{@zafu_tag_count.inspect}"
    end

    def make(mode, opts={})
      if opts[:text]
        custom_text = opts.delete(:text)
      end
      text = custom_text || @text
      opts = @options.merge(opts).merge(:sub => true, :mode => mode, :parent => self)
      new_obj = self.class.new(text, opts)
      if new_obj.success?
        @text = new_obj.text unless custom_text
        new_obj.text = ""
        store new_obj
      else
        flush @text[0..(new_obj.text.length - @text.length)] unless custom_text
      end
      # puts "MADE #{new_obj.inspect}"
      # puts "TEXT #{@text.inspect}"
      new_obj
    end

    def leave(mode=nil)
      if mode.nil?
        @stack = []
        return
      end
      pop  = true
      while @stack != [] && pop
        pop = @stack.pop
        break if pop == mode
      end
    end

    def fail
      @ok   = false
      @stack = []
    end

    def check_params(*args)
      missing = []
      if args[0].kind_of?(Array)
        # or groups
        ok = false
        args.each_index do |i|
          unless args[i].kind_of?(Array)
            missing[i] = [args[i]]
            next
          end
          missing[i] = []
          args[i].each do |arg|
            missing[i] << arg.to_s unless @params[arg]
          end
          if missing[i] == []
            ok = true
            break
          end
        end
        if ok
          return true
        else
          out "[#{@method} parameter(s) missing:#{missing[0].sort.join(', ')}]"
          return false
        end
      else
        args.each do |arg|
          missing << arg.to_s unless @params[arg]
        end
      end
      if missing != []
        out "[#{@method} parameter(s) missing:#{missing.sort.join(', ')}]"
        return false
      end
      true
    end

    def expand_block(block, new_context={})
      block.process(@context.merge(new_context))
    end

    def expand_with(acontext={})

      blocks = acontext.delete(:blocks) || @blocks
      res = ""

      only   = acontext[:only]
      new_context = @context.merge(acontext)

      if acontext[:ignore]
        new_context[:ignore] = (@context[:ignore] || []) + (acontext[:ignore] || []).uniq
      end

      if acontext[:no_ignore]
        new_context[:ignore] = (new_context[:ignore] || []) - acontext[:no_ignore]
      end

      ignore = new_context[:ignore]

      blocks.each do |b|
        if b.kind_of?(String)
          if (!only || (only.kind_of?(Array) && only.include?(:string))) && (!ignore || !ignore.include?(:string))
            res << b
          end
        elsif (!only || (only.kind_of?(Array) && only.include?(b.method)) || only =~ b.method) && (!ignore || !ignore.include?(b.method))
          res << b.process(new_context.dup)
          if pass = b.pass
            new_context.merge!(pass)
          end
        end
      end
      res
    end

    def inspect
      attributes = []
      params = []
      (@params || {}).each do |k,v|
        unless v.nil?
          params << "#{k.inspect.gsub('"', "'")}=>'#{v}'"
        end
      end
      attributes << " {= #{params.sort.join(', ')}}" unless params == []

      context = []
      (@context || {}).each do |k,v|
        unless v.nil?
          context << "#{k.inspect.gsub('"', "'")}=>'#{v}'"
        end
      end
      attributes << " {> #{context.sort.join(', ')}}" unless context == []

      res = []
      @blocks.each do |b|
        if b.kind_of?(String)
          res << b
        else
          res << b.inspect
        end
      end
      result = "[#{@method}#{attributes.join('')}"
      if res != []
        result += "]#{res}[/#{@method}]"
      else
        result += "/]"
      end
      result + @text
    end
  end # Parser
end # Zafu
