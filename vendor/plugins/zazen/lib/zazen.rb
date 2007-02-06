require 'rubygems'
require 'syntax/convertors/html'
require 'redcloth'
require File.join(File.dirname(__FILE__) , 'code_syntax')

module Zena
  module Zazen
    class Parser
      attr_accessor :text
      @@rules = []
      @@after_rules = []
      class << self
        def add_rule(regex, &block)
          @@rules << [regex, block]
        end
        def add_after_rule(regex, &block)
          @@after_rules << [regex, block]
        end
      end
      
      def initialize(text)
        @text = text
        @last_match = nil
      end
  
      def render(options)
        @options = {:images => true}.merge(options)
        extract_code
        render_zazen(@@rules)
        #render_markup
        render_code
        render_zazen(@@after_rules)
        @text
      end
      
      def [](key)
        @options[key]
      end
      
      def helper
        @options[:helper]
      end
      
      def options
        @options
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
          @escaped_code << [$1, $2]
          block_counter += 1
          "<div class='code'>\\ZAZENBLOCKCODE#{block_counter}ZAZENBLOCKCODE\\</div>"
        end
      end
      
      def render_zazen(rules)
        Zazen.parser = self
        rules.each do |regex, block|
          @text.gsub!(regex) { block.call($~) }
        end
      end
      
      def render_code
        @text.gsub!( /\\ZAZENBLOCKCODE(\d+)ZAZENBLOCKCODE\\/ ) do
          lang, text = *(@escaped_code[$1.to_i])
          if lang =~ /class\s*=\s*("|')([^"']+)\1/ && Syntax::SYNTAX[$2]
            convertor = Syntax::Convertors::HTML.for_syntax($2)
            res = convertor.convert( text )
          else
            res = RedCloth.new("<pre>#{text}</pre>").to_html
          end
          "<div#{lang}>#{res}</div>"
        end
        
        @text.gsub!( /\\ZAZENBLOCKAT(\d+)ZAZENBLOCKAT\\/ ) do
          RedCloth.new("<code>#{@escaped_at[$1.to_i]}</code>").to_html
        end
      end
      
      def method_missing(sym, *args)
        @options[:helper].send(sym,*args)
      end
    end
    class << self
      def parser=(parser)
        @@parser = parser
      end
      def options
        @@parser.options
      end
      def helper
        @@parser.helper
      end
      private
      def method_missing(sym, *args)
        @@parser.helper.send(sym, *args)
      end
    end
  end
end


module Zena
  module Zazen
    # create a gallery ![...]!
    Parser.add_rule( /\!\[([^\]]*)\]\!/ ) do |match|
      if options[:images]
        helper.make_gallery(match[1])
      else
        helper.trans('[gallery]')
      end
    end
    
    # list of documents !<.{...}!
    Parser.add_rule( /\!([^0-9]{0,2})\{([^\}]*)\}\!/ ) do |match|
      if options[:images]
        helper.list_nodes(:style=>match[1]], :ids=>match[2])
      else
        helper.trans('[documents]')
      end
    end
    
    # image !<.12.pv/blah blah!:12
    Parser.add_rule( /\!([^0-9]{0,2})([0-9]+)(\.([^\/\!]+)|)(\/([^\!]*)|)\!(:([^\s]+)|)/ ) do |match|
      helper.make_image(:style=>match[1], :id=>match[2], :size=>match[4], :title=>match[6], :link=>match[8], :images=>options[:images])
    end
    
    # link inside the cms "":34
    Parser.add_rule( /"([^"]*)":([0-9]+)/ ) do
      helper.make_link(:title=>match[1],:id=>match[2])
    end
    
    # wiki reference ?zafu? or ?zafu?:http://...
    Parser.add_after_rule( /\?(\w[^\?]+?\w)\?(\s|:TODO TODO TODO)/ ) do
      helper.make_wiki_link(match[1])
    end
  end
end