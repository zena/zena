module Zena
  module Use
    module ZafuEval
      module ViewMethods
        def prefix_project(node)
          node.get_project_id == start_node.get_project_id ? '' : "#{node.project.title} / "
        end
      end

      module ZafuMethods
        def r_eval
          text = @blocks.first
          if !text.kind_of?(String) || @blocks.size > 1
            parser_error("Cannot evaluate RubyLess codes with zafu methods")
          else
            res = RubyLess.translate(text, self)
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