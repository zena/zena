module ParserRules
  module Zazen
    def scan
      if @text =~ /(.*?\s)!\w/
        flush $1
        make(:tag)
      else
        flush
      end
    end
    
    def scan_tag
      if @text =~ /!(\w+)/
        @method = $1
        eat $&
        enter(:param)
      else
        fail
      end
    end
    
    def scan_param
      if @text =~ /(.*?)!(\s|\Z)/
        @params = parse_params($1)
        eat $1, 1
      else
        fail
      end
    end
  end
end