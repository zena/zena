module Zena
  module Use
    module Ajax
      module Common
      end # Common

      module ControllerMethods
        include Common
      end

      module ViewMethods
        include Common

        # Return the DOM id for a node. We had to name this method 'ndom_id' because we want
        # to avoid the clash with Rails' dom_id method.
        def ndom_id(node)
          if node.new_record?
            "#{params[:dom_id]}_form"
          elsif params[:action] == 'create' && !params[:udom_id]
            "#{params[:dom_id]}_#{node.zip}"
          else
            @dom_id || params[:udom_id] || params[:dom_id]
          end
        end

        # RJS to update a page after create/update/destroy
        def update_page_content(page, obj)
          if params[:t_id] && @node.errors.empty?
            @node = secure(Node) { Node.find_by_zip(params[:t_id])}
          end

          base_class = obj.kind_of?(Node) ? Node : obj.class

          if obj.new_record?
            # A. could not create object: show form with errors
            page.replace "#{params[:dom_id]}_form", :file => template_path_from_template_url + "_form.erb"
          elsif @errors || !obj.errors.empty?
            # B. could not update/delete: show errors
            case params[:action]
            when 'destroy', 'drop'
              page.insert_html :top, params[:dom_id], :inline => render_errors
            else
              page.replace "#{params[:dom_id]}_form", :file => template_path_from_template_url + "_form.erb"
            end
          elsif params[:udom_id]
            if params[:udom_id] == '_page'
              # reload page
              page << "document.location.href = document.location.href;"
            else
              # C. update another part of the page
              if node_id = params[:u_id]
                if node_id.to_i != obj.zip
                  if base_class == Node
                    instance_variable_set("@#{base_class.to_s.underscore}", secure(base_class) { base_class.find_by_zip(node_id) })
                  else
                    instance_variable_set("@#{base_class.to_s.underscore}", secure(base_class) { base_class.find_by_id(node_id) })
                  end
                end
              end
              page.replace params[:udom_id], :file => template_path_from_template_url(params[:u_url]) + ".erb"
              if params[:upd_both]
                @dom_id = params[:dom_id]
                page.replace params[:dom_id], :file => template_path_from_template_url + ".erb"
              end
              if params[:done] && params[:action] == 'create'
                page.toggle "#{params[:dom_id]}_form", "#{params[:dom_id]}_add"
                page << params[:done]
              elsif params[:done]
                page << params[:done]
              end
            end
          else
            # D. normal update
            #if params[:dom_id] == '_page'
            #  # reload page
            #  page << "document.location.href = document.location.href;"
            #
            case params[:action]
            when 'edit'
              page.replace params[:dom_id], :file => template_path_from_template_url + "_form.erb"
      #        page << "$('#{params[:dom_id]}_form_t').focusFirstElement();"
            when 'create'
              pos = params[:position]  || :before
              ref = params[:reference] || "#{params[:dom_id]}_add"
              page.insert_html pos.to_sym, ref, :file => template_path_from_template_url + ".erb"
              if obj.kind_of?(Node)
                @node = @node.parent.new_child(:class => @node.class)
              else
                instance_variable_set("@#{base_class.to_s.underscore}", obj.clone)
              end
              page.replace "#{params[:dom_id]}_form", :file => template_path_from_template_url + "_form.erb"
              if params[:done]
                page << params[:done]
              else
                page.toggle "#{params[:dom_id]}_form", "#{params[:dom_id]}_add"
              end
            when 'update'
              page.replace params[:dom_id], :file => template_path_from_template_url + ".erb"
              page << params[:done] if params[:done]
            when 'destroy'
              page.visual_effect :highlight, params[:dom_id], :duration => 0.3
              page.visual_effect :fade, params[:dom_id], :duration => 0.3
            when 'drop'
              case params[:done]
              when 'remove'
                page.visual_effect :highlight, params[:drop], :duration => 0.3
                page.visual_effect :fade, params[:drop], :duration => 0.3
              end
              page.replace params[:dom_id], :file => template_path_from_template_url + ".erb"
            else
              page.replace params[:dom_id], :file => template_path_from_template_url + ".erb"
            end
          end
          page << render_js(false)
        end

        # Used by zafu to set dom_id that need to be made draggable.
        def add_drag_id(dom_id, handle = nil)
          @drag_ids ||= {}
          (@drag_ids[handle] ||= []) << dom_id
        end

        # Used by zafu to transform a dom_id into a droppable element.
        def add_drop_id(dom_id, options)
          js_data << "Droppables.add('#{dom_id}', {hoverclass:'#{options[:hover] || 'drop_hover'}', onDrop:function(element){
  new Ajax.Request('#{options[:url]}', {asynchronous:true, evalScripts:true, method:'put', parameters:'drop=' + encodeURIComponent(element.id)});
}});"
        end

        def render_js(in_html = true)
          if @drag_ids
            @drag_ids.each do |klass, list|
              if klass.nil?
                js_data << %Q{#{list.inspect}.each(Zena.draggable);}
              else
                js_data << %Q{#{list.inspect}.each(function(item) { Zena.draggable(item, #{klass.inspect})})}
              end
            end
          end
          # Super is in Zena::Use::Rendering
          super
        end
      end # ViewMethods

      module ZafuMethods
        def self.included(base)
          base.before_process :process_drag_drop
          base.before_wrap    :wrap_with_drag
        end

        def wrap_with_drag(text)
          if @wrap_with_drag
            @wrap_with_drag.wrap(text)
          else
            text
          end
        end

        # Force an id on the current tag and record the DOM_ID to make the element draggable.
        def process_drag_drop
          drag = @params.delete(:draggable)

          return unless drag || @method == 'drop'

          set_dom_prefix

          if parent.method == 'each' && @method == parent.single_child_method
            node = self.node
            markup = parent.markup
          else
            node = pre_filter_node
            markup = @markup
          end

          markup.tag ||= 'div'

          if drag
            if markup.params[:id]
              # we do not mess with it
              markup = @wrap_with_drag = Zafu::Markup.new('span')
            end

            markup.set_id(node.dom_id)
            markup.append_param(:class, 'drag')

            drag = 'drag_handle' if drag == 'true'

            if drag == 'all'
              # drag full element
              markup.pre_wrap[:drag] = "<% add_drag_id(\"#{node.dom_id(:erb => false)}\") -%>"
            else
              # drag with class handle
              markup.pre_wrap[:drag] = "<% add_drag_id(\"#{node.dom_id(:erb => false)}\", #{drag.inspect}) -%>"
            end
          elsif @method == 'drop'
            markup.set_id(node.dom_id(:list => false))
            markup.append_param(:class, 'drop')

            if hover  = @params.delete(:hover)
              query_params = ", :hover => #{hover.inspect}"
            else
              query_params = ""
            end

            if role = @params.delete(:set) || @params.delete(:add)
              @params["node[#{role}_id]"] = '\#{id}'
            end

            query_params << ", :url => #{make_href(self.name, :action => 'drop')}"
            markup.pre_wrap[:drop] = "<% add_drop_id(\"#{node.dom_id(:erb => false, :list => false)}\"#{query_params}) -%>"
          end
        end

        def r_drop
          r_block
        end

        def r_unlink
          return '' if @context[:make_form]
          opts = {}

          if upd = @params[:update]
            if upd == '_page'
              target = nil
            elsif target = find_target(upd)
              # ok
            else
              return
            end
          elsif target = ancestor('block')
            # ok
          else
            target = self
          end

          opts[:update] = target

          if node.will_be?(Node)
            opts[:cond] = "#{node}.can_write? && #{node}.link_id"
            opts[:action] = 'unlink'
          elsif node.will_be?(Link)
            # ?
            opts[:url] = "/nodes/\#{#{node}.this_zip}/links/\#{#{node}.zip}"
          end

          opts[:default_text] = _('btn_tiny_del')
          @params[:class] ||= 'unlink'

          out "<% if #{node}.can_write? && #{node}.link_id -%>#{@markup.wrap(make_link(opts))}<% end -%>"

         #tag_to_remote
         #"<%= tag_to_remote({:url => node_path(#{node_id}) + \"#{opts[:method] != :put ? '/zafu' : ''}?#{action.join('&')}\", :method => #{opts[:method].inspect}}) %>"
         #  out "<a class='#{@params[:class] || 'unlink'}' href='/nodes/#{erb_node_id}/links/<%= #{node}.link_id %>?#{action}' onclick=\"new Ajax.Request('/nodes/#{erb_node_id}/links/<%= #{node}.link_id %>?#{action}', {asynchronous:true, evalScripts:true, method:'delete'}); return false;\">"
         #  if !@blocks.empty?
         #    inner = expand_with
         #  else
         #    inner = _('btn_tiny_del')
         #  end
         #  out "#{inner}</a><% else -%>#{inner}<% end -%>"
         #elsif node.will_be?(DataEntry)
         #  text = get_text_for_erb
         #  if text.blank?
         #    text = _('btn_tiny_del')
         #  end
         #  out "<%= link_to_remote(#{text.inspect}, {:url => \"/data_entries/\#{#{node}[:id]}?dom_id=#{dom_id}#{upd_url}\", :method => :delete}, :class=>#{(@params[:class] || 'unlink').inspect}) %>"
         #end
        end

      end
    end # Ajax
  end # Use
end # Zena