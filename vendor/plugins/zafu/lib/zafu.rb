Dir.foreach(File.join(File.dirname(__FILE__) , 'rules')) do |file|
  next if file =~ /^\./
  require File.join(File.dirname(__FILE__) , 'rules', file)
end

module Zafu
  class DummyHelper
    def self.method_missing(sym, *args)
      "helper needed for #{sym}(#{args.inspect})"
    end
  end
  # just a wrapper around #Block
  class Parser
    def initialize(text, helper=Zafu::DummyHelper)
      @block = Block.new(text)
    end
    
    def render(context)
      @block.render(context) + @block.rest
    end
  end
  
  module Rules
    # basic rule to render strings
    def dummy
      expand_with
    end
    
    # basic rule to display errors
    def unknown
      sp = ""
      @params.each do |k,v|
        sp += " #{k}=#{v.inspect}"
      end
        
      out "<span class='zafu_unknown'>&lt;z:#{@method}#{sp}&gt;<span class='zafu_unknown'>"
      out expand_with
      out "<span class='zafu_unknown'>&lt;z:/#{@method}&gt;<span class='zafu_unknown'>"
    end
  end
  
  # A Block contains parsed data, ready for compilation
  class Block
    attr_reader :helper
    attr_accessor :rest
    include Zafu::Rules
    # Initialize a new zafu parser. The helper must implement the following methods :
    # template_text_for_url(absolute_url)
    # the method must return the text content or nil
    def initialize(text, method=:dummy, params={}, helper=Zafu::DummyHelper)
      @method = method
      @params = params
      @helper = helper
      @blocks = []
      @rest   = text
      scan
    end
    
    def render(context)
      @context = context
      @result  = ""
      if Zafu::Rules.method_defined?(@method)
        res = self.send(@method)
      else
        res = unknown
      end
        
      if @result != ""
        @result
      else
        res
      end
    end
  
    def out(str)
      @result += str
      nil
    end

    def expand_with(new_context={})
      res = ""
      @blocks.each do |b|
        if b.kind_of?(String)
          res << b
        else
          res << b.render(@context.merge(new_context))
        end
      end
      res
    end
    
    def inspect
      params = ""
      @params.each do |k,v|
        unless v.nil?
          params << " #{k.inspect} => #{v.inspect}"
        end
      end

      context = ""
      (@context || {}).each do |k,v|
        unless v.nil?
          context << " #{k.inspect} => #{v.inspect}"
        end
      end
      
      res = []
      @blocks.each do |b|
        if b.kind_of?(String)
          res << b
        else
          res << b.inspect
        end
      end
      "[#{@method}:#{params.sort.join(' ')}|#{context.sort.join(' ')}]#{res}[/#{@method}]" + @rest
    end
      
    private
    
    # parses to divide the text into sub-blocks
    def scan
      while (@rest != '')
        if @rest =~ /(.*?)<z:(\w+)([^>]*)(\/?)>/m
          # opening block
          @blocks << $1 if $1 != ''
          matched = $&
          closed = ($4 != '')
          method = $2.to_sym
          @rest = @rest[matched.length..-1]
          
          params = scan_params($3)
          block = Block.new(@rest,method,params,@helper)
          @blocks << block
          @rest = block.rest
          block.rest = ""
        elsif @rest =~ /(.*?)<\/z:(\w+)>/m
          # closing block
          @blocks << $1 if $1 != ''
          matched = $&
          method = $2.to_sym
          if method != @method
            @blocks << "<span class='zafu_error'>&lt;/z:#{method}&gt;</span>"
          end
          @rest = @rest[matched.length..-1]
          return
        else
          # no closing tag. eat the end and quit
          @blocks << @rest
          @rest = ''
          return
        end
      end
    end

    def scan_params(text)
      result = {}
      rest = text.strip
      while (rest != '')
        if rest =~ /(.*?)=/
          key = $1.strip.to_sym
          rest = rest[$&.length..-1].strip
          if rest =~ /('|")([^\1]*?[^\\])\1/
            rest = rest[$&.length..-1].strip
            if $1 == "'"
              result[key] = $2.gsub("\\'", "'")
            else
              result[key] = $2.gsub('\\"', '"')
            end
          else
            # error, bad format, return found params.
            return result
          end
        else
          # error, bad format
          return result
        end
      end
      result
    end

    # Retrieve the template text in the current folder or as an absolute path.
    # This method is used when 'including' text
    def find_template_text(url)
      if url == '/'
        # absolute url
        urls = [url,"#{url}/_#{url.split('/').last}"]
      else
        # relative path
        urls = ["#{@context[:current_folder]}/#{url}", "#{@context[:current_folder]}/#{url}/_#{url.split('/').last}",
        "/default/#{url}", "/default/#{url}/_#{url.split('/').last}"]
      end
      text = new_folder = nil
      urls.each do |template_url|
        if text = @helper.template_text_for_url(template_url)
          new_folder = template_url.split('/')[0..-2].join('/')
          break
        end
      end
      text ||= "<span class='zafu_error'>template '#{current_url}' not found</span>"
      return [text, new_folder]
    end
    
    # find the current node name in the context
    def node
      @context[:node] || '@node'
    end
    
    def list
      @context[:list]
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
end