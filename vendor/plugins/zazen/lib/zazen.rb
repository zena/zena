require 'rubygems'
require 'syntax/convertors/html'
require 'redcloth'
require File.join(File.dirname(__FILE__) , 'code_syntax')
module Zazen
  module Rules
    RULES = []
    AFTER_RULES = []
    class << self
      def add_rule(regex, &block)
        RULES << [regex, block]
      end
      def add_after_rule(regex, &block)
        AFTER_RULES << [regex, block]
      end
    end
  end
end
Dir.foreach(File.join(File.dirname(__FILE__) , 'rules')) do |file|
  next if file =~ /^\./
  require File.join(File.dirname(__FILE__) , 'rules', file)
end
module Zazen
  class DummyHelper
    def self.method_missing(sym, *args)
      "helper needed for #{sym}(#{args.inspect})"
    end
  end
  class Parser
    attr_accessor :text, :options, :helper
    
    def initialize(text, helper=Zazen::DummyHelper)
      @text   = text
      @helper = helper
      @last_match = {}
      @options = {}
    end

    def render(options)
      @options = {:images => true, :pretty_code=>true}.merge(options)
      extract_code
      render_zazen(Rules::RULES)
      render_markup
      render_code
      render_zazen(Rules::AFTER_RULES)
      @text
    end
    
    def [](key)
      if key.kind_of?(Symbol)
        @options[key]
      else
        @last_match[key]
      end
    end

    private

    def extract_code
      @escaped_at = []
      block_counter = -1
      @text.gsub!( /(\A|[^\w])@(.*?)@(\Z|[^\w])/ ) do
        @escaped_at << $2
        block_counter += 1
        "#{$1}\\ZAZENBLOCKAT#{block_counter}ZAZENBLOCKAT\\#{$3}"
      end
  
      @escaped_code = []
      block_counter = -1
      @text.gsub!( /<code([^>]*)>(.*?)<\/code>/m ) do
        params, text = $1, $2
        divparams = []
        if params =~ /^(.*)lang\s*=\s*("|')([^"']+)\2(.*)$/
          pre, lang, post = $1.strip, $3, $4.strip
          divparams << pre if pre && pre != ""
          divparams << post if post && post != ""
        else
          divparams << params.strip if params != ''
          lang = ''
        end
        #divparams << "class='code'" unless params =~ /class\s*=/
        divparams.unshift('') if divparams != []
        @escaped_code << [lang, text]
        block_counter += 1
        "<pre#{divparams.join(' ')}>\\ZAZENBLOCKCODE#{block_counter}ZAZENBLOCKCODE\\</pre>"
      end
    end
    
    def render_zazen(rules)
      rules.each do |regex, block|
        @text.gsub!(regex) do
          @last_match = $~
          block.call(self)
        end
      end
    end
    
    def render_markup
      @text = RedCloth.new(@text).to_html
    end
    
    def render_code
      @text.gsub!( /\\ZAZENBLOCKCODE(\d+)ZAZENBLOCKCODE\\/ ) do
        lang, text = *(@escaped_code[$1.to_i])
        if lang != ''
          code_tag = "<code class='#{lang}'>"
        else
          code_tag = '<code>'
        end
        if Syntax::SYNTAX[lang] && @options[:pretty_code]
          convertor = Syntax::Convertors::HTML.for_syntax(lang)
          "#{code_tag}#{convertor.convert( text, false )}</code>"
        else
          RedCloth.new("#{code_tag}#{text}</code>").to_html
        end
      end
      
      @text.gsub!( /\\ZAZENBLOCKAT(\d+)ZAZENBLOCKAT\\/ ) do
        text = @escaped_at[$1.to_i]
        if text =~ /^(\w+)\|/ && Syntax::SYNTAX[$1]
          lang = $1
          if @options[:pretty_code]
            convertor = Syntax::Convertors::HTML.for_syntax(lang)
            res = convertor.convert( text[(lang.length+1)..-1], false )
          else
            res = text[(lang.length+1)..-1]
          end
          res = "<code class='#{lang}'>#{res}</code>"
        else
          res = RedCloth.new("<code>#{text}</code>").to_html
        end
        res
      end
    end
  end
end