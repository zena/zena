module Zafu
  module Action
    # swap an attribute
    # TODO: test
    def r_swap
      if upd = @params[:update]
        if upd == '_page'
          block = nil
        elsif block = find_target(upd)
          # ok
          if ancestor('block') || ancestor('each')
            upd_both = '&upd_both=true'
          else
            upd_both = ''
          end
        else
          return
        end
      elsif ancestor('block') || ancestor('each')
        # ancestor: ok
        block = self
      elsif parent && block = parent.descendant('block')
        # sibling: ok
        upd_both = ''
      else
        return parser_error("missing 'block' in same parent")
      end

      states = ((@params[:states] || 'todo, done') + ' ').split(',').map(&:strip)

      query_params = "node[#{@params[:attr]}]=\#{#{states.inspect}[ ((#{states.inspect}.index(#{node_attribute(@params[:attr])}.to_s) || 0)+1) % #{states.size}]}#{upd_both}"
      out link_to_update(block, :query_params => query_params, :method => :put, :html_params => get_html_params(@params, :link))
    end

    def r_edit
      if @context[:dom_prefix]
        # ajax
        if @context[:in_form]
          # cancel button
          @context[:form_cancel] || ''
        else
          # edit button

          # TODO: show 'reply' instead of 'edit' in comments if visitor != author
          out link_to_update(self, :default_text => _('edit'), :url => "\#{edit_#{base_class.to_s.underscore}_path(#{node_id})}", :html_params => get_html_params(@params, :link), :method => :get, :cond => "#{node}.can_write?", :else => :void)
        end
      else
        # FIXME: we could link to some html page to edit the item.
        ""
      end
    end

    alias r_cancel r_edit

    # TODO: test
    def r_add
      return parser_error("should not be called from within 'each'") if parent.method == 'each'
      return '' if @context[:make_form]

      # why is node = @node (which we need) but we are supposed to have Comments ?
      # FIXME: during rewrite, replace 'node' by 'node(klass = node_class)' so the ugly lines below would be
      # if node.will_be?(Comment)
      #   out "<% if #{node(Node)}.can_comment? -%>"
      # Refs #198.
      if node.will_be?(Comment)
        out "<% if #{node}.can_comment? -%>"
      else
        out "<% if #{node}.can_write? -%>"
      end

      unless descendant('add_btn')
        # add a descendant between self and blocks.
        blocks = @blocks.dup
        @blocks = []
        add_btn = make(:void, :method=>'add_btn', :params=>@params.dup, :text=>'')
        add_btn.blocks = blocks
        remove_instance_variable(:@all_descendants)
      end

      if @context[:form] && @context[:dom_prefix]
        # ajax add

        @html_tag_params.merge!(:id => "#{erb_dom_id}_add")
        @html_tag_params[:class] ||= 'btn_add'
        if @params[:focus]
          focus = "$(\"#{erb_dom_id}_#{@params[:focus]}\").focus();"
        else
          focus = "$(\"#{erb_dom_id}_form_t\").focusFirstElement();"
        end

        out render_html_tag("#{expand_with(:onclick=>"[\"#{erb_dom_id}_add\", \"#{erb_dom_id}_form\"].each(Element.toggle);#{focus}return false;")}")

        if node.will_be?(Node)
          # FIXME: BUG if we set <r:form klass='Post'/> the user cannot select class with menu...
          klass = @context[:klass] || 'Node'
          # FIXME: inspect '@context[:form]' to see if it contains v_klass ?
          out "<% if #{var}_new = secure(Node) { Node.new_from_class(#{klass.inspect}) } -%>"
        else
          out "<% if #{var}_new = #{node_class}.new -%>"
        end

        if @context[:form].method == 'form'
          out expand_block(@context[:form], :in_add => true, :no_ignore => ['form'], :add=>self, :node => "#{var}_new", :parent_node => node, :klass => klass, :publish_after_save => auto_publish_param)
        else
          # build form from 'each'
          out expand_block(@context[:form], :in_add => true, :no_ignore => ['form'], :add=>self, :make_form => true, :node => "#{var}_new", :parent_node => node, :klass => klass, :publish_after_save => auto_publish_param)
        end
        out "<% end -%>"
      else
        # no ajax
        @html_tag_params[:class] ||= 'btn_add' if @html_tag
        out render_html_tag(expand_with)
      end
      out "<% end -%>"
      @html_tag_done = true
    end

    # Show html to add open a popup window to add a document.
    # TODO: inline ajax for upload ?
    def r_add_document
      return parser_error("only works with nodes (not with #{node_class})") unless node.will_be?(Node)
      @html_tag_params[:class] ||= 'btn_add'
      res = "<a href='/documents/new?parent_id=#{erb_node_id}' onclick='uploader=window.open(\"/documents/new?parent_id=#{erb_node_id}\", \"upload\", \"width=400,height=300\");return false;'>#{_('btn_add_doc')}</a>"
      "<% if #{node}.can_write? -%>#{render_html_tag(res)}<% end -%>"
    end

    #if RAILS_ENV == 'test'
    #  def r_test
    #    inspect
    #  end
    #end

    def r_drop
      if parent.method == 'each' && @method == parent.single_child_method
        parent.add_html_class('drop')
      else
        @html_tag_params[:class] ||= 'drop'
      end
      r_block
    end

    def drop_javascript
      hover  = @params[:hover]
      change = @params[:change]

      if role = @params[:set] || @params[:add]
        query_params = ["node[#{role}_id]=[id]"]
      else
        query_params = []
        # set='icon_for=[id], v_status='50', v_title='[v_title]'
        @params.each do |k, v|
          next if [:hover, :change, :done].include?(k)
          value, static = parse_attributes_in_value(v, :erb => false, :skip_node_attributes => true)
          key = change == 'params' ? "params[#{k}]" : "node[#{k}]"
          query_params << "#{key}=#{CGI.escape(value)}"
        end
        return parser_error("missing parameters to set values") if query_params == []
      end

      query_params << "change=#{change}" if change == 'receiver'
      query_params << "t_url=#{CGI.escape(template_url)}"
      query_params << "dom_id=#{erb_dom_id}"
      query_params << start_node_s_param(:erb)
      query_params << "done=#{CGI.escape(@params[:done])}" if @params[:done]

      "<script type='text/javascript'>
      //<![CDATA[
      Droppables.add('#{erb_dom_id}', {hoverclass:'#{hover || 'drop_hover'}', onDrop:function(element){new Ajax.Request('/nodes/#{erb_node_id}/drop?#{query_params.join('&')}', {asynchronous:true, evalScripts:true, method:'put', parameters:'drop=' + encodeURIComponent(element.id)})}})
      //]]>
      </script>"
    end

    def r_draggable
      new_dom_scope
      @html_tag ||= 'div'
      case @params[:revert]
      when 'move'
        revert_effect = 'Element.move'
      when 'remove'
        revert_effect = 'Element.remove'
      else
        revert_effect = 'Element.move'
      end

      res, drag_handle = set_drag_handle_and_id(expand_with, @params, :id => erb_dom_id)

      out render_html_tag(res)

      if drag_handle
        out "<script type='text/javascript'>\n//<![CDATA[\n
          new Draggable('#{erb_dom_id}', {ghosting:true, revert:true, revertEffect:#{revert_effect}, handle:$('#{erb_dom_id}').select('.#{drag_handle}')[0]});\n//]]>\n</script>"
      else
        out "<script type='text/javascript'>\n//<![CDATA[\nZena.draggable('#{erb_dom_id}',0,true,true,#{revert_effect})\n//]]>\n</script>"
      end
    end

    def r_unlink
      return "" if @context[:make_form]
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

      if node.will_be?(Node)
        opts[:cond] = "#{node}.can_write? && #{node}.link_id"
        opts[:url] = "/nodes/\#{#{node_id}}/links/\#{#{node}.link_id}"
      elsif node.will_be?(Link)
        opts[:url] = "/nodes/\#{#{node}.this_zip}/links/\#{#{node}.zip}"
      end

      opts[:method]       = :delete
      opts[:default_text] = _('btn_tiny_del')
      opts[:html_params]  = get_html_params({:class => 'unlink'}.merge(@params), :link)

      out link_to_update(target, opts)

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

  end # Action
end # Zafu