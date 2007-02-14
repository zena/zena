Dir.foreach(File.join(File.dirname(__FILE__) , 'rules')) do |file|
  next if file =~ /^\./
  require File.join(File.dirname(__FILE__) , 'rules', file)
end
class Parser
  attr_accessor :text, :method
  attr_accessor :pass
    
  class << self
    def parser_with_rules(*modules)
      parser = Class.new(Parser)
      modules.each do |mod|
        parser.send(:include, mod)
      end
      parser
    end
    def new_with_url(url, opts={})
      helper = opts[:helper] || Zafu::DummyHelper
      text, absolute_url = self.find_template_text(url,helper)
      current_folder = absolute_url ? absolute_url.split('/')[0..-2].join('/') : '/'
      self.new(text, :helper=>helper, :current_folder=>current_folder, :included_history=>[absolute_url])
    end
    
    # Retrieve the template text in the current folder or as an absolute path.
    # This method is used when 'including' text
    def find_template_text(url, helper, current_folder='/')
      # remove trailing '/'
      if current_folder[-1..-1] == '/'
        current_folder = current_folder[0..-2]
      end
      
      if url[0..0] == '/'
        # absolute url
        urls = [url,"#{url}/_#{url.split('/').last}"]
      else
        # relative path
        urls = ["#{current_folder}/#{url}", "#{current_folder}/#{url}/_#{url.split('/').last}",
        "/default/#{url}", "/default/#{url}/_#{url.split('/').last}"]
      end
      
      text = absolute_url = nil
      urls.each do |template_url|
        if text = helper.send(:template_text_for_url,template_url)
          absolute_url = template_url
          break
        end
      end
      text ||= "<span class='zafu_error'>template '#{url}' not found</span>"
      return [text, absolute_url]
    end
    
  end
  
  def initialize(text, opts={})
    @stack   = []
    @ok      = true
    if opts[:sub]
      @text = text
    else
      @text = before_parse(text)
    end
    @blocks  = []
    
    @options = {:mode=>:void, :method=>'void'}.merge(opts)
    @params  = @options[:params] || {}
    @method  = @options[:method]
    mode     = @options[:mode]
    @options.delete(:params)
    @options.delete(:method)
    @options.delete(:mode)
    start(mode)
    unless opts[:sub]
      @text = after_parse(@text)
    end
    @ok
  end
  
  def start(mode)
    enter(mode)
  end
  
  def render(context={})
    @context = context
    @result  = ""
    @pass    = {} # used to pass information to the parent
    if blocks = @context[@params[:name]]
      # replaced content throught name='..' param
      @context.delete(@params[:name])
      @blocks = blocks
    end
    if self.respond_to?("r_#{@method}".to_sym)
      res = self.send("r_#{@method}".to_sym)
    else
      res = r_unknown
    end
    res ||= ""
    res = @result if @result != ""
    res + @text
  end
  
  def r_void
    expand_with
  end
  alias to_s r_void
  
  def r_with
    return unless @params[:part]
    @pass[@params[:part]] = @blocks
    ""
  end
  
  def r_inspect
    expand_with
    @blocks = []
    self.inspect
  end
  
  def r_include
    expand_with
    @blocks = @included_blocks || @blocks
    expand_with(@pass)
  end
  
  # basic rule to display errors
  def r_unknown
    sp = ""
    @params.each do |k,v|
      sp += " #{k}=#{v.inspect.gsub("'","TMPQUOTE").gsub('"',"'").gsub("TMPQUOTE",'"')}"
    end
      
    res = "<span class='zafu_unknown'>&lt;z:#{@method}#{sp}"
    inner = expand_with
    if inner != ''
      res + "&gt;</span>#{inner}<span class='zafu_unknown'>&lt;z:/#{@method}&gt;</span>"
    else
      res + "/&gt;</span>"
    end
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
    @text, absolute_url = self.class.find_template_text(@params[:template], @options[:helper], @options[:current_folder])
    if absolute_url
      if @options[:included_history].include?(absolute_url)
        @text = "<span class='zafu_error'>[include error: #{(@options[:included_history] + [absolute_url]).join(' --&gt; ')} ]</span>"
      else
        @options[:included_history] += [absolute_url]
        @options[:current_folder] = absolute_url.split('/')[0..-2].join('/')
      end
    end
    @text = before_parse(@text)
    enter(:void) # scan fetched text
    @included_blocks = @blocks
    
    @blocks = []
    @text = text
    enter(:void) # normal scan on content
  end
  def success?
    return @ok
  end
  
  def flush(str=@text)
    if @blocks.last.kind_of?(String)
      @blocks[-1] << str
    else
      @blocks << str
    end
    @text = @text[str.length..-1]
  end
  
  def store(obj)
    if obj.kind_of?(String) && @blocks.last.kind_of?(String)
      @blocks[-1] << obj
    else
      @blocks << obj
    end
  end
  
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
    params = {}
    rest = text.strip
    while (rest != '')
      if rest =~ /(.*?)=/
        key = $1.strip.to_sym
        rest = rest[$&.length..-1].strip
        if rest =~ /('|")([^\1]*?[^\\])\1/
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
    args.each do |arg|
      missing << arg.to_s unless @params[arg]
    end
    if missing != []
      out "[#{@method} parameter(s) missing:#{missing.sort.join(', ')}]"
      return false
    end
    true
  end
  
  def expand_with(new_context={})
    res = ""
    @pass = {} # current object sees some information from it's descendants
    @blocks.each do |b|
      if b.kind_of?(String)
        res << b
      else
        res << b.render(@context.merge(new_context))
        @pass.merge!(b.pass)
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
        else
          pass << "#{k.inspect.gsub('"', "'")}=>'#{v.inspect.gsub('"', "'")}'"
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
  
  def var
    return @var if @var
    if node =~ /^var(\d+)$/
      @var = "var#{$1.to_i + 1}"
    else
      @var = "var1"
    end
  end
end
