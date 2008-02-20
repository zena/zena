Dir.foreach(File.join(File.dirname(__FILE__) , 'rules')) do |file|
  next if file =~ /^\./
  require File.join(File.dirname(__FILE__) , 'rules', file)
end
module ParserModule
  class DummyHelper
    def initialize(strings = {})
      @strings = strings
    end

    def get_template_text(opts)
      src    = opts[:src]
      folder = (opts[:current_folder] && opts[:current_folder] != '') ? opts[:current_folder][1..-1].split('/') : []
      src = src[1..-1] if src[0..0] == '/' # just ignore the 'relative' or 'absolute' tricks.
      url = (folder + src.split('/')).join('_')
      
      if test = @strings[url]
        return [test['src'], url.split('_').join('/')]
      else
        nil
      end
    end

    def template_url_for_asset(opts)
      "/test_#{opts[:type]}/#{opts[:src]}"
    end

    def method_missing(sym, *args)
      arguments = args.map do |arg|
        if arg.kind_of?(Hash)
          res = []
          arg.each do |k,v|
            unless v.nil?
              res << "#{k}:#{v.inspect.gsub(/'|"/, "|")}"
            end
          end
          res.sort.join(' ')
        else
          arg.inspect.gsub(/'|"/, "|")
        end
      end
      res = "[#{sym} #{arguments.join(' ')}]"
    end
  end
end

class Parser
  attr_accessor :text, :method, :pass, :options, :blocks, :params, :ids, :defined_ids, :parent
    
  class << self
    def parser_with_rules(*modules)
      parser = Class.new(Parser)
      modules.each do |mod|
        parser.send(:include, mod)
      end
      parser
    end

    def new_with_url(url, opts={})
      helper = opts[:helper] || ParserModule::DummyHelper.new
      text, absolute_url = self.get_template_text(url,helper)
      current_folder     = absolute_url ? absolute_url.split('/')[1..-2].join('/') : nil
      self.new(text, :helper=>helper, :current_folder=>current_folder, :included_history=>[absolute_url])
    end
    
    # Retrieve the template text in the current folder or as an absolute path.
    # This method is used when 'including' text
    def get_template_text(url, helper, current_folder=nil)
      
      if (url[0..0] != '/') && current_folder
        url = "#{current_folder}/#{url}"
      end
      
      res = helper.send(:get_template_text, :src=>url, :current_folder=>'') || ["<span class='parser_error'>[include] template '#{url}' not found</span>", url]
      return nil unless res
      text, url = *res
      url = "/#{url}" unless url[0..0] == '/' # has to be an absolute path
      return [text, url]
    end
    
  end
  
  def initialize(text, opts={})
    @stack   = []
    @ok      = true
    @blocks  = []
    
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
    @name    ||= @options[:name] || @params[:id]
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
  
  def start(mode)
    enter(mode)
  end
  
  def replace_with(obj)
    @method   = 'void' # (replacer's method is always 'with')
    @blocks   = obj.blocks.empty? ? @blocks : obj.blocks
    @params   = obj.params.empty? ? @params : obj.params
    @params[:id] = @name
  end
  
  def empty?
    @blocks == [] && (@params == {} || @params == {:part => @params[:part]})
  end
  
  def render(context={})
    return '' if context["no_#{@method}".to_sym]
    if @name
      # we pass the name as 'context' in the children tags
      @context = context.merge(:name => @name)
    else
      @context = context
    end
    @result  = ""
    return @result unless before_render
    @pass    = {} # used to pass information to the parent
    res = nil
    if self.respond_to?("r_#{@method}".to_sym)
      res = self.do_method("r_#{@method}".to_sym)
    else
      res = self.do_method(:r_unknown)
    end
    
    if @result != ""
      res = @result
    elsif !res.kind_of?(String)
      res = @method
    end
    after_render(res + @text)
  end
  
  def do_method(sym)
    self.send(sym)
  end
  
  def r_void
    expand_with
  end
  
  def r_ignore
  end
  
  alias to_s r_void
  
  def r_inspect
    expand_with(:preflight=>true)
    @blocks = []
    @pass.merge!(@parts||{})
    self.inspect
  end
  
  # basic rule to display errors
  def r_unknown
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
  
  def before_render
    true
  end
  
  def after_render(text)
    text
  end
  
  def before_parse(text)
    text
  end
  
  def after_parse(text)
    text
  end
  
  def include_template
    return "<span class='parser_error'>[include] missing 'template' attribute</span>" unless @params[:template]
    if @options[:part] && @options[:part] == @params[:part]
      # fetching only a part, do not open this element (same as original caller) as it is useless and will make us loop the loop.
      @method = 'ignore'
      enter(:void)
      return
    end
    @method = 'void'
    
    # fetch text
    @options[:included_history] ||= []
    
    included_text, absolute_url = self.class.get_template_text(@params[:template], @options[:helper], @options[:current_folder])
    
    absolute_url += "::#{@params[:part].gsub('/','_')}"  if @params[:part]
    absolute_url += "??#{@options[:part].gsub('/','_')}" if @options[:part]
    if absolute_url
      if @options[:included_history].include?(absolute_url)
        included_text = "<span class='parser_error'>[include] infinity loop: #{(@options[:included_history] + [absolute_url]).join(' --&gt; ')}</span>"
      else
        included_history  = @options[:included_history] + [absolute_url]
        current_folder    = absolute_url.split('/')[1..-2].join('/')
      end
    end
    res = self.class.new(included_text, :helper=>@options[:helper], :current_folder=>current_folder, :included_history=>included_history, :part => @params[:part]) # we set :part to avoid loop failure when doing self inclusion
    
    if @params[:part]
      if iblock = res.ids[@params[:part]]
        included_blocks = [iblock]
        # get all ids from inside the included part:
        @ids.merge! iblock.defined_ids
      else
        included_blocks = ["<span class='parser_error'>[include] '#{@params[:part]}' not found in template '#{@params[:template]}'</span>"]
      end
    else
      included_blocks = res.blocks
      @ids.merge! res.ids
    end
    
    enter(:void) # normal scan on content
    # replace 'with'
    
    not_found = []
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
        not_found << "<span class='parser_error'>[with] '#{b.params[:part]}' not found in template '#{@params[:template]}'</span>"
      end
    end
    @blocks = included_blocks + not_found
  end
  
  # Return a has of all descendants. Find a specific descendant with descendant['form'] for example.
  def descendants
    @descendants ||= begin
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
  
  def ancestors
    @ancestors ||= begin
      if parent
        parent.ancestors + [parent]
      else
        []
      end
    end
  end
  
  alias public_descendants descendants
  
  # Return the last defined parent for the given key.
  def ancestor(key)
    res = nil
    ancestors.reverse_each do |a|
      if key == a.method
        res = a
        break
      end
    end
    res
  end
  
  # Return the last defined descendant for the given key.
  def descendant(key)
    (descendants[key] || []).last
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
  
  # Set output during render
  def out(obj)
    @result << obj
  end
  
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
    opts = @options.merge(opts).merge(:sub=>true, :mode=>mode, :parent => self)
    
    new_obj = self.class.new(text,opts)
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
  
  # Parse parameters into a hash. This parsing supports multiple values for one key by creating additional keys:
  # <tag do='hello' or='goodbye' or='gotohell'> creates the hash {:do=>'hello', :or=>'goodbye', :or1=>'gotohell'}
  def parse_params(text)
    return {} unless text
    return text if text.kind_of?(Hash)
    params = {}
    rest = text.strip
    while (rest != '')
      if rest =~ /(.+?)=/
        key = $1.strip.to_sym
        rest = rest[$&.length..-1].strip
        if rest =~ /('|")(|[^\1]*?[^\\])\1/
          rest = rest[$&.length..-1].strip
          key_counter = 1
          while params[key]
            key = "#{key}#{key_counter}".to_sym
            key_counter += 1
          end
            
          if $1 == "'"
            params[key] = $2.gsub("\\'", "'")
          else
            params[key] = $2.gsub('\\"', '"')
          end
        else
          # error, bad format, return found params.
          break
        end
      else
        # error, bad format
        break
      end
    end
    params
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
    block.render(@context.merge(new_context))
  end
  
  def expand_with(acontext={})
    blocks = acontext.delete(:blocks) || @blocks
    res = ""
    
    # FIXME: I think we can delete @pass and @parts stuff now (test first).
    
    @pass  = {} # current object sees some information from it's direct descendants
    @parts = {}
    only   = acontext[:only]
    new_context = @context.merge(acontext)
    blocks.each do |b|
      if b.kind_of?(String)
        if !only || only.include?(:string)
          res << b
        end
      elsif !only || only.include?(b.method)
        res << b.render(new_context.dup)
        if pass = b.pass
          if pass[:part]
            @parts.merge!(pass[:part])
            pass.delete(:part)
          end
          @pass.merge!(pass)
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
    
    pass = []
    (@pass || {}).each do |k,v|
      unless v.nil?
        if v.kind_of?(Array)
          pass << "#{k.inspect.gsub('"', "'")}=>#{v.inspect.gsub('"', "'")}"
        elsif v.kind_of?(Parser)
          pass << "#{k.inspect.gsub('"', "'")}=>['#{v}']"
        else
          pass << "#{k.inspect.gsub('"', "'")}=>#{v.inspect.gsub('"', "'")}"
        end
      end
    end
    attributes << " {< #{pass.sort.join(', ')}}" unless pass == []
    
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
end
