module Zena
  module Use
    module Forms

      module ZafuMethods
        def make_form
          return super unless form_helper = @context[:form_helper]

          case method
          when 'title', 'link'
            name = @params[:attr] || 'title'
            out "<%= #{form_helper}.text_field :#{name} %>"
          else
            super
          #when 'text', 'summary'
          #  make_textarea(:name => method)
          #when :r_show
          #  make_input(:name => (@params[:attr] || @params[:tattr]), :date => @params[:date])
          #when :r_text
          #  make_textarea(:name => 'text')
          #when :r_summary
          #  make_textarea(:name => 'summary')
          #when :r_zazen
          #  make_textarea(:name => @params[:attr])
          #else
          #  if node.will_be?(DataEntry) && @method.to_s =~ /node_/
          #    # select node_id
          #    "<%= select_id('#{base_class.to_s.underscore}', '#{@method}_id') %>"
          #  end
          end
          #res = "<#{@html_tag || 'div'} class='zazen'>#{res}</#{@html_tag || 'div'}>" if [:r_summary, :r_text].include?(method)
        end

        def form_options
          opts = super

          dom_name = node.dom_prefix
          opts[:form_helper] = 'f'

          if template_url = @context[:template_url]
            # Ajax

            base_name = self.base_class.to_s.underscore

            if @context[:in_add]
              # Inline form used to create new elements: set values to '' and 'parent_id' from context
              opts[:id]          = "#{node.dom_prefix}_form"
              opts[:form_tag]    = "<% remote_form_for(:#{base_name}, #{node}, :url => #{base_name.pluralize}_path, :html => {:id => \"#{dom_name}_form_t\"}) do |f| %>"
              opts[:form_cancel] = "<p class='btn_x'><a href='#' onclick='[\"#{dom_name}_add\", \"#{dom_name}_form\"].each(Element.toggle);return false;'>#{_('btn_x')}</a></p>\n"
            else
              # Saved form
              opts[:id]          = "<%= dom_id(#{node}) %>"

              opts[:form_tag]    = <<-END_TXT
<% remote_form_for(:#{base_name}, #{node}, :url => #{node}.new_record? ? #{base_name.pluralize}_path : #{base_name}_path(#{node}), :method => #{node}.new_record? ? :post : :put, :html => {:id => \"#{dom_name}_form_t\"}) do |f| %>
END_TXT

              opts[:form_cancel] = <<-END_TXT
<% if #{node}.new_record? -%>
  <p class='btn_x'><a href='#' onclick='[\"<%= params[:dom_id] %>_add\", \"<%= params[:dom_id] %>_form\"].each(Element.toggle);return false;'>#{_('btn_x')}</a></p>
<% else -%>
  <p class='btn_x'><%= link_to_remote(#{_('btn_x').inspect}, :url => #{base_class.to_s.underscore}_path(#{node}.id) + \"/zafu?t_url=#{CGI.escape(template_url)}&dom_id=\#{params[:dom_id]}#{@context[:need_link_id] ? "&link_id=\#{#{node}.link_id}" : ''}\", :method => :get) %></p>
<% end -%>
END_TXT
            end
          end
          opts
        end

        def form_hidden_fields(opts)
          hidden_fields = super

          set_fields = []
          @markup.params[:class] ||= 'form'
          var_name   = base_class.to_s.underscore
          (descendants('input') + descendants('select')).each do |tag|
            set_fields << "#{var_name}[#{tag.params[:name]}]"
          end

          if template_url = @context[:template_url] # @context[:dom_prefix] || @params[:update]
            # Ajax

            if (descendants('input') || []).detect {|elem| elem.params[:type] == 'submit'}
              # has submit
            else
              # Hidden submit for Firefox compatibility
              hidden_fields['submit'] = ["<input type='submit'/>"]
            end

            hidden_fields['link_id'] = "<%= #{node}.link_id %>" if @context[:need_link_id]

            # if @params[:update] || (@context[:add] && @context[:add].params[:update])
            #   upd = @params[:update] || @context[:add].params[:update]
            #   if target = find_target(upd)
            #     hidden_fields['u_url']   = target.template_url
            #     hidden_fields['udom_id'] = target.erb_dom_id
            #     hidden_fields['u_id']    = "<%= #{@context[:parent_node]}.zip %>" if @context[:in_add]
            #     hidden_fields['s']       = start_node_s_param(:value)
            #   end
            # elsif (block = ancestor('block')) && node.will_be?(DataEntry)
            #   # updates template url
            #   hidden_fields['u_url']   = block.template_url
            #   hidden_fields['udom_id'] = block.erb_dom_id
            # end

            hidden_fields['t_url'] = template_url

            # if t_id = @params[:t_id]
            #   hidden_fields['t_id']  = parse_attributes_in_value(t_id)
            # end

            # FIXME: replace 'dom_id' with 'dom_name' ?
            erb_dom_id = @context[:saved_template] ? '<%= params[:dom_id] %>' : node.dom_prefix

            hidden_fields['dom_id'] = erb_dom_id

            if node.will_be?(Node)
              # Nested contexts:
              # 1. @node
              # 2. var1 = @node.children
              # 3. var1_new = Node.new
              hidden_fields['node[parent_id]'] = "<%= #{@context[:in_add] ? "#{node.up.up}.zip" : "#{node}.parent_zip"} %>"
            elsif node.will_be?(Comment)
              # FIXME: the "... || '@node'" is a hack and I don't understand why it's needed...
              hidden_fields['node_id'] = "<%= #{node.up || '@node'}.zip %>"
            elsif node.will_be?(DataEntry)
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
          end

          if node.will_be?(Node) && (@params[:klass] || @context[:klass])
            hidden_fields['node[klass]']    = @params[:klass] || @context[:klass]
          end

          if node.will_be?(Node) && @params[:mode]
            hidden_fields['mode'] = @params[:mode]
          end

          hidden_fields['node[v_status]'] = Zena::Status[:pub] if @context[:publish_after_save] || auto_publish_param

          # ===
          # TODO: reject set_fields from hidden_fields
          # ===

          hidden_fields.reject! do |k,v|
            set_fields.include?(k)
          end

          hidden_fields
        end

        # transform a 'show' tag into an input field.
        #def make_input(params = @params)
        #  input, attribute = get_input_params(params)
        #  return parser_error("missing 'name'") unless attribute
        #  return '' if attribute == 'parent_id' # set with 'r_form'
        #  return '' if ['url','path'].include?(attribute) # cannot be set with a form
        #  if params[:date]
        #  input_id = @context[:dom_prefix] ? ", :id=>\"#{dom_id}_#{attribute}\"" : ''
        #    return "<%= date_box('#{base_class.to_s.underscore}', #{params[:date].inspect}#{input_id}) %>"
        #  end
        #  input_id = node.dom_prefix ? " id='#{node.dom_prefix}_#{attribute}'" : ''
        #  "<input type='#{params[:type] || 'text'}'#{input_id} name='#{input[:name]}' value='#{input[:value]}'/>"
        #end
        #
        ## Parse params to extract everything that is relevant to building input fields.
        ## TODO: refactor
        #def get_input_params(params = @params)
        #  res = {}
        #  if res[:name] = (params[:name] || params[:date])
        #    #if res[:name] =~ /\A([\w_]+)\[(.*?)\]/
        #    #  attribute, sub_attr = $1, $2
        #    #else
        #      attribute = res[:name]
        #    #end
        #
        #    unless @context[:in_filter] || attribute == 's'
        #      #if sub_attr
        #      #  res[:name] = "#{base_class.to_s.underscore}[#{attribute}][#{sub_attr}]"
        #      #else
        #        res[:name] = "#{base_class.to_s.underscore}[#{attribute}]"
        #      #end
        #    end
        #
        #    #if sub_attr
        #    #  if (nattr = node_attribute(attribute)) != 'nil'
        #    #    nattr = "#{nattr}[#{sub_attr.inspect}]"
        #    #  end
        #    #else
        #    if type = node.klass.safe_method_type([attribute.to_sym])
        #      res[:value] = "<%= fquote #{type[:method]} %>"
        #    end
        #    #end
        #
        #    #if sub_attr && params[:type] == 'checkbox' && !params[:value]
        #    #  # Special case when we have a sub_attribute: default value for "tagged[foobar]" is "foobar"
        #    #  params[:value] = sub_attr
        #    #end
        #
        #    #if @context[:in_add]
        #    #  res[:value] = (params[:value] || params[:set_value]) ? ["'#{ helper.fquote(params[:value])}'"] : ["''"]
        #    #elsif @context[:in_filter]
        #    #  res[:value] = attribute ? ["'<%= fquote params[#{attribute.to_sym.inspect}] %>'"] : ["''"]
        #    #elsif params[:value]
        #    #  res[:value] = ["'#{ helper.fquote(params[:value])}'"]
        #    #else
        #    #  if nattr != 'nil'
        #    #    res[:value] = ["'<%= fquote #{nattr} %>'"]
        #    #  else
        #    #    res[:value] = ["''"]
        #    #  end
        #    #end
        #  end
        #
        #  if @context[:dom_prefix]
        #    res[:id]   = "#{erb_dom_id}_#{attribute}"
        #  else
        #    res[:id]   = params[:id] if params[:id]
        #  end
        #
        #  if params[:type] == 'checkbox' && nattr
        #    if value = params[:value]
        #      res[:checked] = "<%= #{nattr} == #{value.inspect} ? \" checked='checked'\" : '' %>"
        #    else
        #      res[:checked] = "<%= #{nattr}.blank? ? '' : \" checked='checked'\" %>"
        #    end
        #  end
        #
        #  [:size, :style, :class].each do |k|
        #    res[k] = params[k] if params[k]
        #  end
        #
        #  return [res, attribute]
        #end

        # TODO: add parent_id into the form !
        # TODO: add <div style="margin:0;padding:0"><input name="_method" type="hidden" value="put" /></div> if method == put
        # FIXME: use <r:form href='self'> or <r:form action='...'>

=begin
          form << "<%= error_messages_for(#{node}) %>"


          @blocks = blocks_bak if blocks_bak

          @html_tag_done = false
          @html_tag_params.merge!(id_hash)
          out render_html_tag(res)
=end
      protected

          def auto_publish_param(in_string = false)
            if in_string
              %w{true force}.include?(@params[:publish]) ? "&publish=#{@params[:publish]}" : ''
            else
              @params[:publish]
            end
          end

          # Returns true if a form/edit needs to keep track of link_id (l_status or l_comment used).
          def need_link_id
            if (input_fields = (descendants('input') + descendants('select'))) != []
              input_fields.each do |f|
                return true if f.params[:name] =~ /\Al_/
              end
            elsif (show_fields = descendants('show')) != []
              show_fields.each do |f|
                return true if f.params[:attr] =~ /\Al_/
              end
            end
            return false
          end
      end
    end # Forms
  end # Use
end # Zena