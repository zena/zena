module Zena
  module Use
    module ZafuEval
      module ViewMethods
        def zafu_eval(node, code, opts)
          # Setup macro rendering context
          if opts[:template]
            master_template = secure(Node) { Node.find_by_zip(opts[:template]) }
          end
          path = opts[:zafu_url]
          parser = ::Zena::ZafuCompiler.new(code,
            :helper => self,
            :base_path        => path,
            :included_history => [path],
            :root             => path,
            :master_template  => master_template
          )
          
          # Setup starting context (note that a lot of the contextual information 
          # is lost: no up values).
          _node = node
          node_context = Zena::Use::NodeContext.new('_node', node.vclass)

          erb = parser.to_erb(
            :dev => false,
            :node => node_context,
            :master_template => master_template
          )
          # Geez if this works...
          ERB.new(erb).result(binding)
        rescue => err
          err.message
        end
      end
      
      module ZafuMethods
        def r_zafu_eval
          return parser_error("Missing 'code' parameter.") unless code = params[:code]
          return parser_error("Not a node context.") unless node.will_be?(Node)
          code = RubyLess.translate(self, code)
          zafu_url = @options[:root]
          master   = @context[:master_template]
          out "<%= zafu_eval(#{node.to_s}, #{code}, :zafu_url => #{zafu_url.inspect}, :template => #{master ? master.zip : 'nil'}) %>"
        end
        
        def r_eval
          text = @blocks.first
          if !text.kind_of?(String) || @blocks.size > 1
            parser_error("Cannot evaluate RubyLess codes with zafu methods")
          else
            res = RubyLess.translate(self, text)
            if res.literal.kind_of?(String)
              erb_escape res.literal
            else
              "<%= #{res} %>"
            end
          end
        end
      end # ZafuMethods
    end # ZafuEval
  end # Use
end # Zena