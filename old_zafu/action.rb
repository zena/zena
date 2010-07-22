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

    #if RAILS_ENV == 'test'
    #  def r_test
    #    inspect
    #  end
    #end

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

  end # Action
end # Zafu