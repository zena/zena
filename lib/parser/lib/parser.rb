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
  attr_accessor :text, :method, :pass, :options, :blocks, :params
    
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
      
      res = helper.send(:get_template_text, :src=>url, :current_folder=>'') || ["<span class='parser_error'>template '#{url}' not found</span>", url]
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
    @params  = @options[:params]
    @method  = @options[:method]
    mode     = @options[:mode]
    @options.delete(:params)
    @options.delete(:method)
    @options.delete(:mode)
    
    if opts[:sub]
      @text = text
    else
      @text = before_parse(text)
    end
    
    start(mode)
    
    unless opts[:sub]
      @text = after_parse(@text)
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
  end
  
  def empty?
    @blocks == [] && (@params == {} || @params == {:part => @params[:part]})
  end
  
  def render(context={})
    return '' if context["no_#{@method}".to_sym]
    @context = context
    return '' unless before_render
    @result  = ""
    @pass    = {} # used to pass information to the parent
    res = nil
    if self.respond_to?("r_#{@method}".to_sym)
      res = self.send("r_#{@method}".to_sym)
    else
      res = r_unknown
    end
    if @result != ""
      res = @result
    elsif !res.kind_of?(String)
      res = @method
    end
    after_render(res + @text)
  end
  
  def r_with
    return unless part = @params[:part]
    if @context[:preflight]
      @pass[:part] = {part => self}
      ""
    else
      r_void
    end
  end
  
  def r_void
    expand_with
  end
  
  alias to_s r_void
  
  def r_inspect
    expand_with(:preflight=>true)
    @blocks = []
    @pass.merge!(@parts||{})
    self.inspect
  end
  
  def r_include
    expand_with(:preflight=>true)
    if @parts != {}
      # first definitions in inclusion history have precedence
      expand_with(:parts  => (@parts).merge(@context[:parts] || {}), :blocks => @included_blocks)
    else
      expand_with(:blocks => @included_blocks)
    end
  end
  
  # basic rule to display errors
  def r_unknown
    sp = ""
    @params.each do |k,v|
      sp += " #{k}=#{v.inspect.gsub("'","TMPQUOTE").gsub('"',"'").gsub("TMPQUOTE",'"')}"
    end
      
    res = "<span class='parser_unknown'>&lt;z:#{@method}#{sp}"
    inner = expand_with
    if inner != ''
      res + "&gt;</span>#{inner}<span class='parser_unknown'>&lt;z:/#{@method}&gt;</span>"
    else
      res + "/&gt;</span>"
    end
  end
  
  def before_render
    # name param is propagated into children (used to label parts of a large template)
    if @params && (name = @params[:name])
      if @context[:name]
        @context[:name] += "/#{name}"
      else
        @context[:name] = name
      end
      if replacer = (@context[:parts] || {})[@context[:name]]
        return false if replacer.empty?
        replace_with(replacer)
        @params[:name] = name # in case replaced again
      end
    end
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
    # fetch text
    text = @text
    @options[:included_history] ||= []
    
    @text, absolute_url = self.class.get_template_text(@params[:template], @options[:helper], @options[:current_folder])
    
    absolute_url += "::#{@params[:part].gsub('/','_')}" if @params[:part]
    if absolute_url
      if @options[:included_history].include?(absolute_url)
        @text = "<span class='parser_error'>[include error: #{(@options[:included_history] + [absolute_url]).join(' --&gt; ')} ]</span>"
      else
        @options[:included_history] += [absolute_url]
        @options[:current_folder]    = absolute_url.split('/')[1..-2].join('/')
      end
    end
    
    @text = before_parse(@text)
    enter(:void) # scan fetched text
    if @params[:part]
      @included_blocks = [find_part(@params[:part])]
    else
      @included_blocks = @blocks
    end
    
    @blocks = []
    @text = text
    enter(:void) # normal scan on content
  end
  
  def find_part(path)
    res    = self
    found  = []
    path.split('/').reject {|e| e==''}.each do |name|
      if res = find_name(res.blocks, name)
        found << name
      else
        return "<span class='parser_error'>'#{(found + [name]).join('/')}' not found in template '#{@params[:template]}'</span>"
      end
    end
    res
  end
  
  def find_name(blocks, name)
    blocks.each do |b|
      next if b.kind_of?(String)
      return b if b.params[:name] == name
      next if b.params[:name] # bad name
      if res = find_name(b.blocks,name)
        return res
      end
    end
    return nil
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
      custom_text = opts[:text]
      opts.delete(:text)
    end
    text = custom_text || @text
    opts = @options.merge(opts).merge(:sub=>true, :mode=>mode)
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
  
  def parse_params(text)
    return {} unless text
    params = {}
    rest = text.strip
    while (rest != '')
      if rest =~ /(.+?)=/
        key = $1.strip.to_sym
        rest = rest[$&.length..-1].strip
        if rest =~ /('|")([^\1]*?[^\\]|)\1/
          rest = rest[$&.length..-1].strip
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
    @pass  = {} # current object sees some information from it's direct descendants
    @parts = {}
    
    new_context = @context.merge(acontext)
    blocks.each do |b|
      if b.kind_of?(String)
        res << b
      else
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
