module Zena
  class CodeSyntax
    include Zena::Code::DefaultSyntax
    def initialize(text, code_lang)
      @text = text
      @code_lang = code_lang
    end
    
    protected
      def basic_to_html(inline, code_class)
        if inline
          ::RedCloth.new("<code class='#{code_class}'>#{@text}</code>").to_html
        else
          ::RedCloth.new("<pre class='#{code_class}'>#{@text}</pre>").to_html
        end
      end
  end
end # Zena