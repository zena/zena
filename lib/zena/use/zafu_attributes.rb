module Zena
  module Use
    module ZafuAttributes
      module ViewMethods
        def prefix_project(node)
          node.get_project_id == start_node.get_project_id ? '' : "#{node.project.title} / "
        end
      end

      module ZafuMethods
        def self.included(base)
          base.before_process :filter_prefix, :filter_status, :filter_actions, :filter_property
        end

        private
          # Rewrite things like <tt><h1 do='age' live='true'/></tt> to
          # <tt><h1 do='show' attr='age' live='true'/></tt>
          def filter_property
            keys = @params.keys
            return if keys & [:live, :edit] == []
            if type = node.klass.safe_method_type([@method])
              @params[:attr] = @method
              @method = 'show'
            end
          end

          def filter_prefix
            if prefix = @params.delete(:prefix)
              prefix.split(',').map(&:strip).each do |cond_prefix|
                case cond_prefix
                when 'project'
                  if node.will_be?(Node)
                    out "<%= prefix_project(#{node}) %>"
                  end
                when 'lang'
                  out r_wrong_lang(:text => '[#{v.lang}] ')
                else
                  # parser error
                end
              end
            end
          end # filter_prefix

          def filter_status
            status = @params.delete(:status)
            if status == 'true' || (@params[:actions] && status != 'false')
              @markup.tag ||= 'span'
              @markup.append_dyn_param(:class, "s<%= #{node(Node)}.version.status %>")
            end
          end

          def filter_actions
            if actions = @params.delete(:actions)
              if publish = @params.delete(:publish)
                out_post " <%= node_actions(#{node}, :actions => #{actions.inspect}, :publish_after_save => #{publish.inspect}) %>"
              else
                out_post " <%= node_actions(#{node}, :actions => #{actions.inspect}) %>"
              end
            end
          end
      end # ZafuMethods
    end # ZafuAttributes
  end # Use
end # Zena