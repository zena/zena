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
          base.before_process :filter_prefix, :filter_status, :filter_property, :filter_anchor
          base.before_wrap :add_anchor
        end

        private

          # Enable 'a' tag anchoring
          def filter_anchor
            if @method == 'anchor'
              @method = 'void'
              if single_child_method == 'link'
                @blocks.first.params[:anchor] ||= 'true'
                return
              else
                @params[:anchor] ||= 'true'
              end
            end

            if anchor_name = @params.delete(:anchor)
              if anchor_name == 'true'
                if node.will_be?(Node)
                  anchor_name = 'node#{id}'
                elsif node.will_be?(Version)
                  anchor_name = 'version#{node.id}_#{id}'
                else
                  # force compilation with Node context
                  node_bak = @context[:node]
                  @context[:node] = node(Node)
                    anchor_name = ::RubyLess.translate_string(anchor_name, self)
                  @context[:node] = node_bak
                end
              end

              if @markup.tag == 'a' || @method == 'link'
                markup = @markup
              else
                markup = @anchor_tag = ::Zafu::Markup.new('a')
              end
              markup.append_param(:class, 'anchor')
              set_markup_attr(markup, :name, anchor_name)
            end
          end

          def add_anchor(text)
            if @anchor_tag
              @anchor_tag.wrap('') + text
            else
              text
            end
          end

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

              if node.will_be? Node
                accessor = "#{node}.version"
              elsif node.will_be? Version
                accessor = node
              else
                accessor = "#{node(Node)}.version"
              end

              @markup.tag ||= 'span'
              @markup.append_dyn_param(:class, "s<%= #{accessor}.status %>")
            end
          end

          def steal_and_eval_html_params_for(markup, params)
            markup.steal_keys.each do |key|
              next unless value = params.delete(key)
              append_markup_attr(markup, key, value)
            end
          end
      end # ZafuMethods
    end # ZafuAttributes
  end # Use
end # Zena