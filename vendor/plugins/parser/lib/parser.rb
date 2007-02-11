Dir.foreach(File.join(File.dirname(__FILE__) , 'rules')) do |file|
  next if file =~ /^\./
  require File.join(File.dirname(__FILE__) , 'rules', file)
end

class Parser
  attr_accessor :text
  attr_accessor :pass
  class << self
    def parser_with_rules(*modules)
      parser = Class.new(Parser)
      modules.each do |mod|
        parser.send(:include, mod)
      end
      parser
    end
  end
  
  def initialize(text, opts={})
    @quit    = false
    @ok      = true
    @text    = text
    @out     = []
    @insight = {} # current object sees some information from it's descendants
    @pass    = {} # used to pass information to the parent
    
    @options = {:mode=>:void, :method=>'void'}.merge(opts)
    @params  = @options[:params]
    @method  = @options[:method]
    mode     = @options[:mode]
    @options.delete(:params)
    @options.delete(:method)
    @options.delete(:mode)
    enter(mode)
    @ok
  end
  
  def render(context={})
    @context = context
    @result  = ""
    if self.respond_to?("r_#{@method}".to_sym)
      res = self.send("r_#{@method}".to_sym)
    else
      res = r_unknown
    end
    
    res = @result if @result != ""
    res + @text
  end
  
  def r_void
    expand_with
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
  
  def success?
    return @ok
  end
  
  def scan_void
    while (@text != '' && !@quit)
      scan
    end
  end
  
  def flush(str=@text)
    out str
    eat str
  end
  
  def out(obj)
    if obj.kind_of?(String) && @out.last.kind_of?(String)
      @out[-1] += obj
    else
      @out << obj
    end
  end
  
  def eat(*args)
    len = 0
    args.each do |arg|
      if arg.kind_of?(String)
        len += arg.length
      elsif arg.kind_of?(Fixnum)
        len += arg
      else
        raise
      end
    end
    @text = @text[len..-1]
  end
  
  def enter(mode)
    self.send("scan_#{mode}".to_sym)
  end
  
  def make(mode, opts={})
    text = opts[:text] || @text
    opts = @options.merge(opts)
    new_obj = self.class.new(text,opts)
    if new_obj.success?
      @text = new_obj.text unless opts[:text]
      @insight = @insight.merge(new_obj.pass)
      new_obj.text = ""
      out new_obj
    else
      flush @text[0..(new_obj.text.length - @text.length)] unless opts[:text]
    end
  end
  
  def quit
    @quit = true
  end
  
  def fail
    @ok = false
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
  
  def expand_with(new_context={})
    res = ""
    @out.each do |b|
      if b.kind_of?(String)
        res << b
      else
        res << b.render(@context.merge(new_context))
      end
    end
    res
  end
  
  def inspect
    params = []
    (@params || {}).each do |k,v|
      unless v.nil?
        params << "#{k}=>'#{v}'"
      end
    end
    
    insight = []
    (@insight || {}).each do |k,v|
      unless v.nil?
        insight << "#{k}=>'#{v}'"
      end
    end
    
    context = []
    (@context || {}).each do |k,v|
      unless v.nil?
        context << "#{k}=>'#{v}'"
      end
    end
    
    attributes = []
    [params, context, insight].each do |attrib|
      attributes << " {#{attrib.sort.join(', ')}}" unless attrib == []
    end
    attributes.unshift '' unless attributes == []
    
    res = []
    @out.each do |b|
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
