module Zena
  module Use
    module ZafuEval
      module ZafuMethods
        def r_eval
          text = @blocks.first
          if !text.kind_of?(String) || @blocks.size > 1
            parser_error("Cannot evaluate RubyLess codes with zafu methods")
          else
            res = RubyLess.translate(self, text)
            if res.literal.kind_of?(String)
              res.literal
            else
              "<%= #{res} %>"
            end
          end
        end
      end # ZafuMethods
    end # ZafuEval
  end # Use
end # Zena