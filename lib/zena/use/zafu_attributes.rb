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
          base.before_process :filter_prefix, :filter_status, :filter_property, :filter_anchor, :filter_live, :filter_set_var
          base.before_wrap :add_live_id
          base.after_wrap  :add_anchor
        end

        private

          # Enable 'a' tag anchoring
          def filter_anchor
            # anchor has a different meaning with 'link' (used to point link).
            return if @method == 'link'

            if @method == 'anchor'
              @method = 'void'
              @params[:anchor] ||= 'true'
              #if single_child_method == 'link'
              #  @blocks.first.params[:anchor] ||= 'true'
              #  return
              #else
              #  @params[:anchor] ||= 'true'
              #end
            end

            if anchor_name = get_anchor_name(@params.delete(:anchor))
              if @markup.tag == 'a' || @method == 'link'
                markup = @markup
              else
                markup = @anchor_tag = Zafu::Markup.new('a')
                markup.space_before  = @markup.space_before
                @markup.space_before = nil
              end
              markup.append_param(:class, 'anchor')
              set_markup_attr(markup, :name, anchor_name)
            end
          end

          def add_anchor(text)
            if @anchor_tag
              anchor = @anchor_tag.wrap('')
              @anchor_tag = nil
              anchor + text
            else
              text
            end
          end

          # Remove 'live' param so that it does not alter RubyLess method building.
          def filter_live
            @live_param = @params.delete(:live)
          end

          # Evaluate 'set_xxx' param and store result in context with 'var' name. This name
          # will be used during RubyLess method resolution.
          def filter_set_var
            @params.keys.each do |k|
              if k.to_s =~ /^set_(.+)$/
                var  = $1
                code = @params.delete(k)
                begin
                  typed_string = ::RubyLess.translate(code, self)
                  set_context_var('set_var', var, typed_string)
                rescue RubyLess::NoMethodError => err
                  parser_error(err.message, code)
                end
              end
            end
          end

          # If we had a 'live' parameter, wrap the result with an id.
          # TODO: we could replace the id with a class so that multiple instances on a page do not
          # cause problems.
          def add_live_id(text)
            if @live_param == 'true'
              if name = @params[:attr]
                # ok
              elsif @method =~ /\(\s*([\w_]+)\s*\)/
                name = $1
              else
                name = @method
              end

              erb_id = "_#{name}<%= #{node}.zip %>"

              tag ||= @method =~ /^zazen/ ? 'div' : 'span'

              if @markup.has_param?(:id) || !@out_post.blank?
                # Do not overwrite id or use span if we have post content (actions) that would disappear on live update.
                "<#{tag} id='#{erb_id}'>#{text}</#{tag}>"
              else
                @markup.tag ||= tag
                @markup.set_dyn_param(:id, erb_id)
                text
              end
            else
              text
            end
          end

          # Rewrite things like <tt><h1 do='age' live='true'/></tt> to
          # <tt><h1 do='show' attr='age' live='true'/></tt>
          def filter_property
            return if node.list_context?
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
                  out r_wrong_lang
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