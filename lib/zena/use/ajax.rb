module Zena
  module Use
    module Ajax
      module ViewMethods
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
          unless params[:dom_id]
            # simply reply with failure or success
            if !@node.errors.empty?
              page << "alert(#{@node.errors.first.join(': ')});"
              page << "return false;" # How to avoid 'onSuccess' ?
            elsif params[:udom_id] == '_page'
              # reload page
              page << "document.location.href = document.location.href;"
            else
              # ?
            end
            return
          end

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
              page.replace params[:dom_id], :file => template_path_from_template_url + ".erb"
              puts "$('#{params[:dom_id]}_form_t').focusFirstElement();"
              page << "$('#{params[:dom_id]}_form_t').focusFirstElement();"
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
        def add_drag_id(dom_id, js_options = nil)
          @drag_ids ||= {}
          (@drag_ids[js_options] ||= []) << dom_id
        end

        # Used by zafu to transform a dom_id into a droppable element.
        def add_drop_id(dom_id, options)
          js_data << "Droppables.add('#{dom_id}', {hoverclass:'#{options[:hover] || 'drop_hover'}', onDrop:function(element){
  new Ajax.Request('#{options[:url]}', {asynchronous:true, evalScripts:true, method:'put', parameters:'drop=' + encodeURIComponent(element.id)});
}});"
        end

        def add_toggle_id(dom_id, group_name, role)
          @toggle_ids ||= {}
          unless list = @toggle_ids[group_name]
            list = @toggle_ids[group_name] = []

            if other = yield
              found = other.rel[role].other_zips
            else
              found = []
            end
            url = "/nodes/#{other.zip}"
            js_data << "#{group_name} = {\"list\":#{found.inspect}, \"url\":#{url.inspect}, \"role\":#{role.inspect}};"
          end
          list << dom_id
        end

        def filter_form(node, dom_id)
          js_data << %Q{new Form.Observer('#{dom_id}', 0.3, function(element, value) {new Ajax.Request('#{zafu_node_path(node)}', {asynchronous:true, evalScripts:true, method:'get', parameters:Form.serialize('#{dom_id}')})});}
        end

        # Include draggable ids in bottom of page Javascript.
        def render_js(in_html = true)
          if @drag_ids
            @drag_ids.each do |js_options, list|
              if js_options.nil?
                js_data << %Q{#{list.inspect}.each(Zena.draggable);}
              else
                js_data << %Q{#{list.inspect}.each(function(item) { Zena.draggable(item, #{js_options})});}
              end
            end
          end

          if @toggle_ids
            @toggle_ids.each do |group_name, list|
              js_data << %Q{#{list.inspect}.each(function(item) { Zena.set_toggle(item, #{group_name})});}
            end
          end

          # Super is in Zena::Use::Rendering
          super
        end
      end # ViewMethods

      module ZafuMethods
        def self.included(base)
          # TODO: move process_drag, process_toggle in 'before_wrap' callback so that 'node' properly set.
          base.before_process :process_drag, :process_toggle
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
        def process_drag
          return unless drag = @params.delete(:draggable)

          if @markup.params[:id]
            # we do not mess with it
            markup = @wrap_with_drag = Zafu::Markup.new('span')
          else
            markup = @markup
          end

          markup.tag ||= 'div'

          node = pre_filter_node

          if @name.blank?
            # make sure we have a scope
            set_dom_prefix(node)
          end

          # We do not want to use the same id as the 'each' loop but we also want to
          # avoid changing the node context
          @drag_prefix ||= root.get_unique_name('drag', true).gsub(/[^\d\w\/]/,'_')
          markup.set_id(node.dom_id(:dom_prefix => @drag_prefix))

          markup.append_param(:class, 'drag')

          drag = 'drag_handle' if drag == 'true'

          if drag == 'all'
            js_options = ['false']
          else
            unless @blocks.detect{|b| b.kind_of?(String) ? b =~ /class=.#{drag}/ : (b.params[:class] == drag || (b.markup && b.markup.params[:class] == drag))}
              handle = "<span class='#{drag}'>&nbsp;</span>"
            end
            js_options = [drag.inspect]
          end

          if revert = @params.delete(:revert)
            js_options << (%w{true false}.include?(revert) ? revert : revert.inspect)
          end

          markup.pre_wrap[:drag] = "#{handle}<% add_drag_id(\"#{node.dom_id(:dom_prefix => @drag_prefix, :erb => false)}\", #{js_options.join(', ').inspect}) -%>"
        end

        # Display an input field to filter a remote block
        def r_filter
          if upd = @params[:update]
            return unless block = find_target(upd)
          else
            return parser_error("missing 'block' in same parent") unless parent && block = parent.descendant('block')
          end

          return parser_error("cannot use 's' as key (used by start_node)") if @params[:key] == 's'

          dom_id = node.dom_id(:erb => false)

          out %Q{<%= form_remote_tag(:url => zafu_node_path(#{node}.zip), :method => :get, :html => {:id => \"#{dom_id}_f\"}) %>
          <div class='hidden'>
            <input type='hidden' name='t_url' value='#{template_url(upd)}'/>
            <input type='hidden' name='dom_id' value='#{upd}'/>
            <input type='hidden' name='s' value='<%= start_node_zip %>'/>
          </div><div class='wrapper'>
          }
          if @blocks == []
            out "<input type='text' name='#{@params[:key] || 'f'}' value='<%= params[#{(@params[:key] || 'f').to_sym.inspect}] %>'/>"
          else
            out expand_with(:in_filter => true)
          end
          out "</div></form>"
          if @params[:live] || @params[:update]
            out "<% filter_form(#{node}, \"#{dom_id}_f\") -%>"
          end
        end

        # Create a drop block.
        def r_drop
          if parent.method == 'each' && @method == parent.single_child_method
            # We reuse the 'each' block.
            markup = parent.markup
            # Make sure the parent has a proper dom_prefix.
            parent.set_dom_prefix
          else
            set_dom_prefix
            markup = @markup
          end

          markup.tag ||= 'div'

          # This dom_id detection code is crap but it fixes the drop in each bug.
          if dom_id = markup.dyn_params[:id]
            if dom_id =~ /<%= %Q\{(.*)\} %>/
              dom_id = $1
            end
          else
            dom_id = node.dom_id(:list => false, :erb => false)
            markup.set_id(node.dom_id(:list => false))
          end

          markup.append_param(:class, 'drop') unless markup.params[:class] =~ /drop/

          if hover  = @params.delete(:hover)
            query_params = ", :hover => #{hover.inspect}"
          else
            query_params = ""
          end

          if role = @params.delete(:set) || @params.delete(:add)
            @params["node[#{role}_id]"] = '\#{id}'
          end

          query_params << ", :url => #{make_href(self.name, :action => 'drop')}"
          markup.pre_wrap[:drop] = "<% add_drop_id(\"#{dom_id}\"#{query_params}) -%>"
          r_block
        end

        # Create a link to toggle relation on/off
        def r_toggle
          return parser_error("missing 'set' or 'add' parameter") unless role = @params.delete(:set) || @params.delete(:add)
          return parser_error("missing 'for' parameter") unless finder = @params.delete(:for)

          finder = RubyLess.translate(self, finder)
          return parser_error("Invalid class 'for' parameter: #{finder.klass}") unless finder.klass <= Node

          set_dom_prefix
          dom_id = node.dom_id(:erb => false)
          markup.set_id(node.dom_id)
          markup.append_param(:class, 'toggle')
          out "<% add_toggle_id(\"#{dom_id}\", #{var.inspect}, #{RubyLess.translate_string(self, role)}) { #{finder} } -%>#{expand_with}"
        end

        def process_toggle
          return unless role = @params.delete(:toggle)

          unless finder = @params.delete(:for)
            out parser_error("missing 'for' parameter")
            return
          end

          finder = RubyLess.translate(self, finder)
          unless finder.klass <= Node
            out parser_error("Invalid class 'for' parameter: #{finder.klass}")
            return
          end

          node = pre_filter_node

          if dom_id = @markup.params[:id]
            # we do not mess with it
          else
            set_dom_prefix
            markup.set_id(node.dom_id)
            dom_id = node.dom_id(:erb => false)
          end

          markup.tag ||= 'div'

          markup.append_param(:class, 'toggle')
          markup.pre_wrap[:toggle] = "<% add_toggle_id(\"#{dom_id}\", #{"#{var}_tog".inspect}, #{RubyLess.translate_string(self, role)}) { #{finder} } -%>"
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
            opts[:action] = 'unlink'
          elsif node.will_be?(Link)
            # ?
            opts[:url] = "/nodes/\#{#{node}.this_zip}/links/\#{#{node}.zip}"
          end

          opts[:default_text] = _('btn_tiny_del')
          @params[:class] ||= 'unlink'

          out "<% if #{node}.can_write? && #{node}.link_id -%>#{wrap(make_link(opts))}<% end -%>"

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

        protected

          def need_ajax?(each_block)
            return false unless each_block
            # Inline editable
            super ||
            # unlink
            each_block.descendant('unlink')
          end

      end
    end # Ajax
  end # Use
end # Zena