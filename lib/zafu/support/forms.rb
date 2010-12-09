module Zafu
  module Support
    module Forms

      def r_textarea
        out make_textarea(@html_tag_params.merge(@params))
        @html_tag_done = true
      end

      # <r:select name='klass' root_class='...'/>
      # <r:select name='parent_id' values='projects in site'/>
      # TODO: optimization (avoid loading full AR to only use [id, name])
      def r_select
        html_attributes, attribute = get_input_params()
        return parser_error("missing name") unless attribute
        if value = @params[:selected]
          # FIXME: DRY with html_attributes
          value = value.gsub(/\[([^\]]+)\]/) do
            node_attr = $1
            res = node_attribute(node_attr)
            "\#{#{res}}"
          end
          selected = value.inspect
        elsif @context[:in_filter]
          selected = "params[#{attribute.to_sym.inspect}].to_s"
        else
          selected = "#{node_attribute(attribute)}.to_s"
        end
        html_id = html_attributes[:id] ? " id='#{html_attributes[:id]}'" : ''
        if @context[:in_filter]
          select_tag = "<select#{html_id} name='#{attribute}'>"
        else
          select_tag = "<select#{html_id} name='#{base_class.to_s.underscore}[#{attribute}]'>"
        end

        if klass = @params[:root_class]
          class_opts = {}
          class_opts[:without]   = @params[:without]  if @params[:without]
          # do not use 'selected' if the node is not new
          "#{select_tag}<%= options_for_select(Node.classes_for_form(:class => #{klass.inspect}#{params_to_erb(class_opts)}), (#{node}.new_record? ? #{selected} : #{node}.klass)) %></select>"
        elsif @params[:type] == 'time_zone'
          # <r:select name='d_tz' type='time_zone'/>
          "#{select_tag}<%= options_for_select(TZInfo::Timezone.all_identifiers, #{selected}) %></select>"
        elsif options_list = get_options_for_select
          "#{select_tag}<%= options_for_select(#{options_list}, #{selected}) %></select>"
        else
          parser_error("missing 'nodes', 'root_class' or 'values'")
        end
      end


      def r_input
        html_attributes, attribute = get_input_params()
        case @params[:type]
        when 'select' # FIXME: why is this only for classes ?
          out parser_error("please use [select] here")
          r_select
        when 'date_box', 'date'
          return parser_error("date_box without name") unless attribute
          input_id = @context[:dom_prefix] ? ", :id=>\"#{dom_id}_#{attribute}\"" : ''
          "<%= date_box '#{base_class.to_s.underscore}', #{attribute.inspect}, :size=>15#{@context[:in_add] ? ", :value=>''" : ''}#{input_id} %>"
        when 'id'
          return parser_error("select id without name") unless attribute
          name = "#{attribute}_id" unless attribute[-3..-1] == '_id'
          input_id = @context[:erb_dom_id] ? ", :input_id =>\"#{erb_dom_id}_#{attribute}\"" : ''
          "<%= select_id('#{base_class.to_s.underscore}', #{attribute.inspect}#{input_id}) %>"
        when 'time_zone'
          out parser_error("please use [select] here")
          r_select
        when 'submit'
          @html_tag = 'input'
          @html_tag_params[:type] = @params[:type]
          @html_tag_params[:text] = @params[:text] if @params[:text]
          @html_tag_params.merge!(html_attributes)
          render_html_tag(nil)
        else
          # 'text', 'hidden', ...
          @html_tag = 'input'
          @html_tag_params[:type] = @params[:type] || 'text'
          if checked = html_attributes.delete(:checked)
            @html_tag_params.merge!(html_attributes)
            render_html_tag(nil, checked)
          else
            @html_tag_params.merge!(html_attributes)
            render_html_tag(nil)
          end
        end
      end

      def r_form_tag
        # replace <form> with constructed form
        "#{@context[:form_tag]}#{expand_with(:form_tag => nil)}</form>"
      end

      # TODO: add parent_id into the form !
      # TODO: add <div style="margin:0;padding:0"><input name="_method" type="hidden" value="put" /></div> if method == put
      # FIXME: use <r:form href='self'> or <r:form action='...'>
      def r_form
        hidden_fields = {}
        set_fields = []
        id_hash    = {:class => @html_tag_params[:class] || @params[:class] || 'form'}
        var_name   = base_class.to_s.underscore
        (descendants('input') + descendants('select')).each do |tag|
          set_fields << "#{var_name}[#{tag.params[:name]}]"
        end

        if @context[:dom_prefix] || @params[:update]
          # ajax
          if @context[:in_add]
            # inline form used to create new elements: set values to '' and 'parent_id' from context
            id_hash[:id] = "#{erb_dom_id}_form"
            id_hash[:style] = "display:none;"

            cancel =  "<p class='btn_x'><a href='#' onclick='[\"#{erb_dom_id}_add\", \"#{erb_dom_id}_form\"].each(Element.toggle);return false;'>#{_('btn_x')}</a></p>\n"
            form  =  "<%= form_remote_tag(:url => #{base_class.to_s.underscore.pluralize}_path, :html => {:id => \"#{dom_id}_form_t\"}) %>\n"
          else
            # saved form

            id_hash[:id] = erb_dom_id

            cancel = !@context[:dom_prefix] ? "" : <<-END_TXT
  <% if #{node}.new_record? -%>
    <p class='btn_x'><a href='#' onclick='[\"<%= params[:dom_id] %>_add\", \"<%= params[:dom_id] %>_form\"].each(Element.toggle);return false;'>#{_('btn_x')}</a></p>
  <% else -%>
    <p class='btn_x'><%= link_to_remote(#{_('btn_x').inspect}, :url => #{base_class.to_s.underscore}_path(#{node_id}) + \"/zafu?t_url=#{CGI.escape(template_url)}&dom_id=\#{params[:dom_id]}#{@context[:need_link_id] ? "&link_id=\#{#{node}.link_id}" : ''}\", :method => :get) %></p>
  <% end -%>
  END_TXT
            form =<<-END_TXT
  <% if #{node}.new_record? -%>
  <%= form_remote_tag(:url => #{base_class.to_s.underscore.pluralize}_path, :html => {:id => \"\#{params[:dom_id]}_form_t\"}) %>
  <% else -%>
  <%= form_remote_tag(:url => #{base_class.to_s.underscore}_path(#{node_id}), :method => :put, :html => {:id => \"#{dom_id}_form_t\"}) %>
  <% end -%>
  END_TXT
          end

          if (descendants('input') || []).select{|elem| elem.params[:type] == 'submit'} != []
            # has submit
          else
            hidden_submit = "<input type='submit'/>" # hidden submit for Firefox compatibility
          end

          hidden_fields['link_id'] = "<%= #{node}.link_id %>" if @context[:need_link_id]

          if @params[:update] || (@context[:add] && @context[:add].params[:update])
            upd = @params[:update] || @context[:add].params[:update]
            if target = find_target(upd)
              hidden_fields['u_url']   = target.template_url
              hidden_fields['udom_id'] = target.erb_dom_id
              hidden_fields['u_id']    = "<%= #{@context[:parent_node]}.zip %>" if @context[:in_add]
              hidden_fields['s']       = start_node_s_param(:value)
            end
          elsif (block = ancestor('block')) && node_kind_of?(DataEntry)
            # updates template url
            hidden_fields['u_url']   = block.template_url
            hidden_fields['udom_id'] = block.erb_dom_id
          end

          hidden_fields['t_url'] = template_url
          if t_id = @params[:t_id]
            hidden_fields['t_id']  = parse_attributes_in_value(t_id)
          end

          erb_dom_id = @context[:saved_template] ? '<%= params[:dom_id] %>' : self.erb_dom_id

          hidden_fields['dom_id'] = erb_dom_id

          if node_kind_of?(Node)
            hidden_fields['node[parent_id]'] = "<%= #{@context[:in_add] ? "#{@context[:parent_node]}.zip" : "#{node}.parent_zip"} %>"
          elsif node_kind_of?(Comment)
            # FIXME: the "... || '@node'" is a hack and I don't understand why it's needed...
            hidden_fields['node_id'] = "<%= #{@context[:parent_node] || '@node'}.zip %>"
          elsif node_kind_of?(DataEntry)
            hidden_fields["data_entry[#{@context[:data_root]}_id]"] = "<%= #{@context[:in_add] ? @context[:parent_node] : "#{node}.#{@context[:data_root]}"}.zip %>"
          end

          if add_block = @context[:add]
            params = add_block.params
            [:after, :before, :top, :bottom].each do |sym|
              if params[sym]
                hidden_fields['position'] = sym.to_s
                if params[sym] == 'self'
                  if sym == :before
                    hidden_fields['reference'] = "#{erb_dom_id}_add"
                  else
                    hidden_fields['reference'] = "#{erb_dom_id}_form"
                  end
                else
                  hidden_fields['reference'] = params[sym]
                end
                break
              end
            end
            if params[:done] == 'focus'
              if params[:focus]
                hidden_fields['done'] = "'$(\"#{erb_dom_id}_#{@params[:focus]}\").focus();'"
              else
                hidden_fields['done'] = "'$(\"#{erb_dom_id}_form_t\").focusFirstElement();'"
              end
            elsif params[:done]
              hidden_fields['done'] = CGI.escape(params[:done]) # .gsub("NODE_ID", @node.zip).gsub("PARENT_ID", @node.parent_zip)
            end
          else
            # ajax form, not in 'add'
            hidden_fields['done'] = CGI.escape(@params[:done]) if @params[:done]
          end
        else
          # no ajax
          # FIXME
          cancel = "" # link to normal node ?
          form = "<form method='post' action='/nodes/#{erb_node_id}'><div style='margin:0;padding:0'><input name='_method' type='hidden' value='put' /></div>"
        end

        if node_kind_of?(Node) && (@params[:klass] || @context[:klass])
          hidden_fields['node[klass]']    = @params[:klass] || @context[:klass]
        end

        if node_kind_of?(Node) && @params[:mode]
          hidden_fields['mode'] = @params[:mode]
        end

        hidden_fields['node[v_status]'] = Zena::Status[:pub] if @context[:publish_after_save] || auto_publish_param

        form << "<div class='hidden'>"
        hidden_fields.each do |k,v|
          next if set_fields.include?(k)
          v = "'#{v}'" unless v.kind_of?(String) && ['"', "'"].include?(v[0..0])
          form << "<input type='hidden' name='#{k}' value=#{v}/>\n"
        end
        form << hidden_submit << "\n" if hidden_submit
        form << "</div>"

        form << "<%= error_messages_for(#{node}) %>"

        if !descendant('cancel') && !descendant('edit')
          if !descendant('form_tag')
            # add a descendant before blocks.
            blocks_bak = @blocks
            @blocks = @blocks.dup
            @blocks = [make(:void, :method=>'void', :text=>cancel)] + blocks_bak
          else
            form   = cancel + form
            cancel = ''
          end
        end

        if descendant('form_tag')
          res = expand_with(:form_tag => form, :in_form => true, :form_cancel => cancel, :erb_dom_id => erb_dom_id, :dom_id => dom_id)
        else
          res = form + expand_with(:in_form => true, :form_cancel => cancel, :erb_dom_id => erb_dom_id, :dom_id => dom_id) + '</form>'
        end

        @blocks = blocks_bak if blocks_bak

        @html_tag_done = false
        @html_tag_params.merge!(id_hash)
        out render_html_tag(res)
      end

      # <r:checkbox role='collaborator_for' values='projects' in='site'/>"
      # TODO: implement checkbox in the same spirit as 'r_select'
      def r_checkbox
        return parser_error("missing 'nodes'") unless values = @params[:values] || @params[:nodes]
        return parser_error("missing 'role'")   unless   role = (@params[:role] || @params[:name])
        attribute = @params[:attr] || 'name'
        if role =~ /(.*)_ids?\Z/
          role = $1
        end
        meth = role.singularize

        if values =~ /^\d+\s*($|,)/
          # ids
          # TODO generate the full query instead of using secure.
          values = values.split(',').map{|v| v.to_i}
          list_finder = "(secure(Node) { Node.find(:all, :conditions => 'zip IN (#{values.join(',')})') })"
        else
          # relation
          list_finder, klass = build_finder_for(:all, values)
          return unless list_finder
          return parser_error("invalid class (#{klass})") unless klass.ancestors.include?(Node)
        end
        out "<% if (#{list_var} = #{list_finder}) && (#{list_var}_relation = #{node}.relation_proxy(#{role.inspect})) -%>"
        out "<% if #{list_var}_relation.unique? -%>"

        out "<% #{list_var}_id = #{list_var}_relation.other_id -%>"
        out "<div class='input_radio'><% #{list_var}.each do |#{var}| -%>"
        out "<span><input type='radio' name='node[#{meth}_id]' value='#{erb_node_id(var)}'<%= #{list_var}_id == #{var}[:id] ? \" checked='checked'\" : '' %>/> <%= #{node_attribute(attribute, :node=>var)} %></span> "
        out "<% end -%></div>"
        out "<input type='radio' name='node[#{meth}_id]' value=''/> #{_('none')}"

        out "<% else -%>"

        out "<% #{list_var}_ids = #{list_var}_relation.other_ids -%>"
        out "<div class='input_checkbox'><% #{list_var}.each do |#{var}| -%>"
        out "<span><input type='checkbox' name='node[#{meth}_ids][]' value='#{erb_node_id(var)}'<%= #{list_var}_ids.include?(#{var}[:id]) ? \" checked='checked'\" : '' %>/> <%= #{node_attribute(attribute, :node=>var)} %></span> "
        out "<% end -%></div>"
        out "<input type='hidden' name='node[#{meth}_ids][]' value=''/>"

        out "<% end -%><% end -%>"
      end

      alias r_radio r_checkbox

      protected


        def get_input_params(params = @params)
          res = {}
          if res[:name] = (params[:name] || params[:date])
            if res[:name] =~ /\A([\w_]+)\[(.*?)\]/
              attribute, sub_attr = $1, $2
            else
              attribute = res[:name]
            end

            unless @context[:in_filter] || attribute == 's'
              if sub_attr
                res[:name] = "#{base_class.to_s.underscore}[#{attribute}][#{sub_attr}]"
              else
                res[:name] = "#{base_class.to_s.underscore}[#{attribute}]"
              end
            end

            if sub_attr
              if (nattr = node_attribute(attribute)) != 'nil'
                if sub_attr == ''
                  sub_attr = params[:value] || ''
                end
                nattr = "#{nattr}[#{sub_attr.inspect}]"
              end
            else
              nattr = node_attribute(attribute)
            end

            if sub_attr && params[:type] == 'checkbox' && !params[:value]
              # Special case when we have a sub_attribute: default value for "tagged[foobar]" is "foobar"
              params[:value] = sub_attr
            end

            if @context[:in_add]
              res[:value] = (params[:value] || params[:set_value]) ? ["'#{ helper.fquote(params[:value])}'"] : ["''"]
            elsif @context[:in_filter]
              res[:value] = attribute ? ["'<%= fquote params[#{attribute.to_sym.inspect}] %>'"] : ["''"]
            elsif params[:value]
              res[:value] = ["'#{ helper.fquote(params[:value])}'"]
            else
              if nattr != 'nil'
                res[:value] = ["'<%= fquote #{nattr} %>'"]
              else
                res[:value] = ["''"]
              end
            end
          end

          if @context[:dom_prefix]
            res[:id]   = "#{erb_dom_id}_#{attribute}"
          else
            res[:id]   = params[:id] if params[:id]
          end

          if params[:type] == 'checkbox' && nattr
            if value = params[:value]
              res[:checked] = "<%= #{nattr} == #{value.inspect} ? \" checked='checked'\" : '' %>"
            else
              res[:checked] = "<%= #{nattr}.blank? ? '' : \" checked='checked'\" %>"
            end
          end

          [:size, :style, :class].each do |k|
            res[k] = params[k] if params[k]
          end

          return [res, attribute]
        end

        def get_options_for_select
          if nodes = @params[:nodes]
            # TODO: dry with r_checkbox
            if nodes =~ /^\d+\s*($|,)/
              # ids
              # TODO: optimization generate the full query instead of using secure.
              nodes = nodes.split(',').map{|v| v.to_i}
              nodes = "(secure(Node) { Node.find(:all, :conditions => 'zip IN (#{nodes.join(',')})') })"
            else
              # relation
              nodes, klass = build_finder_for(:all, nodes)
              return unless nodes
              return parser_error("invalid class (#{klass})") unless klass.ancestors.include?(Node)
            end
            set_attr  = @params[:attr] || 'id'
            show_attr = @params[:show] || 'name'
            options_list = "[['','']] + (#{nodes} || []).map{|r| [#{node_attribute(show_attr, :node => 'r', :node_class => Node)}, #{node_attribute(set_attr, :node => 'r', :node_class => Node)}.to_s]}"
          elsif values = @params[:values]
            options_list = values.split(',').map(&:strip)

            if show = @params[:show]
              show_values = show.split(',').map(&:strip)
            elsif show = @params[:tshow]
              show_values = show.split(',').map do |s|
                _(s.strip)
              end
            end

            if show_values
              options_list.each_index do |i|
                options_list[i] = [show_values[i], options_list[i]]
              end
            end
            options_list.inspect
          end
        end

        # transform a 'show' tag into an input field.
        def make_input(params = @params)
          input, attribute = get_input_params(params)
          return parser_error("missing 'name'") unless attribute
          return '' if attribute == 'parent_id' # set with 'r_form'
          return '' if ['url','path'].include?(attribute) # cannot be set with a form
          if params[:date]
          input_id = @context[:dom_prefix] ? ", :id=>\"#{dom_id}_#{attribute}\"" : ''
            return "<%= date_box('#{base_class.to_s.underscore}', #{params[:date].inspect}#{input_id}) %>"
          end
          input_id = @context[:dom_prefix] ? " id='#{erb_dom_id}_#{attribute}'" : ''
          "<input type='#{params[:type] || 'text'}'#{input_id} name='#{input[:name]}' value=#{input[:value]}/>"
        end

        # transform a 'zazen' tag into a textarea input field.
        def make_textarea(params)
          return parser_error("missing 'name'") unless name = params[:name]
          if name =~ /\A([\w_]+)\[(.*?)\]/
            attribute = $2
          else
            attribute = name
            name = "#{base_class.to_s.underscore}[#{attribute}]"
          end
          return '' if attribute == 'parent_id' # set with 'r_form'

          if @blocks == [] || @blocks == ['']
            if @context[:in_add]
              value = ''
            else
              value = attribute ? "<%= #{node_attribute(attribute)} %>" : ""
            end
          else
            value = expand_with
          end
          html_id = @context[:dom_prefix] ? " id='#{erb_dom_id}_#{attribute}'" : ''
          "<textarea#{html_id} name='#{name}'>#{value}</textarea>"
        end

        def default_focus_field
          if (input_fields = descendants('input')) != []
            field = input_fields.first.params[:name]
          elsif (show_fields = descendants('show')) != []
            field = show_fields.first.params[:attr]
          elsif node_kind_of?(Node)
            field = 'v_title'
          else
            field = 'text'
          end
        end
    end # Forms
  end # Support
end # Zafu