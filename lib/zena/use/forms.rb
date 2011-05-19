module Zena
  module Use
    module Forms
      module ViewMethods

        # Create a new instance of the given class name
        def new_instance(class_name, params = {})
          return nil unless klass = Node.get_class(class_name, :create => true)
          klass.new_instance(Node.transform_attributes(params))
        end

        def make_checkbox(node, opts)
          if relation_name = opts[:role]
            values, attribute = opts[:list], opts[:attr]
            relation_proxy = node.relation_proxy(relation_name)
            return nil unless values && relation_proxy

            res = []
            role = relation_proxy.other_role

            if relation_proxy.unique?
              current_value = relation_proxy.other_id
              values.each do |value|
                res << ("<input type='radio' name='node[#{role}_id]' value='#{value.zip}'" +
                (current_value == value.id ? " checked='checked'/> " : '/> ') +
                "<span>#{value.prop[attribute]}</span>")
              end
              res << "<input type='radio' name='node[#{role}_id]' value=''/> <span>#{_('none')}</span>"
            else
              current_values = relation_proxy.other_ids
              res << "<input type='hidden' name='node[#{role}_ids][]' value=''/>"
              values.each do |value|
                res << ("<span><input type='checkbox' name='node[#{role}_ids][]' value='#{value.zip}'" +
                (current_values.include?(value.id) ? " checked='checked'/> " : '/> ') +
                "<span>#{value.prop[attribute]}</span>")
              end
            end
            res.join('')
          else
            # literal values
            list, name, selected = opts[:list], opts[:name], opts[:selected]
            show = opts[:show] || list
            if selected.kind_of?(Array)
              selected = selected.map(&:to_s)
              name = "node[#{name}][]"
            else
              selected = [selected.to_s]
              name = "node[#{name}]"
            end
            res = []
            res << "<input type='hidden' name='#{name}' value=''/>"
            list.each_with_index do |value, i|
              res << ("<input type='checkbox' name='#{name}' value='#{value}'" +
              (selected.include?(value.to_s) ? " checked='checked'/> " : '/> ') +
              "<span>#{show[i]}</span>")
            end
            res.join('')
          end
        end

        # Find a params value from an input name (q[foo] ==> safe params[q][foo])
        def param_value(name)
          # q[foo.bar][xxx]
          list = name.gsub(']','').split('[')
          # q foo.bar xxx
          base = params
          while true
            key = list.shift
            if base.kind_of?(Hash)
              base = base[key]
            else
              return nil
            end
            break if list.empty?
          end
          base
        end
      end # ViewMethods

      module ZafuMethods

        # Enter the context of a newly created object
        def r_new
          return parser_error("missing 'klass' parameter") unless class_name = @params[:klass]
          return parser_error("invalid 'klass' parameter") unless klass = get_class(class_name)
          return parser_error("invalid 'klass' parameter (not a Node)") unless klass <= Node

          res  = []
          keys = {:klass => 'klass'}
          @params.each do |key, value|
            next if key == :klass
            # TODO: maybe it would be safer to check with [:"key="] and change safe_property to
            # authorize both ?
            next unless type = klass.safe_method_type([key.to_s])
            # Store how to access current value to show hidden field in form.
            keys[key] = type[:method]
            code = RubyLess.translate(self, value)
            if code.klass == type[:class]
              res << ":#{key} => #{code}"
            else
              out parser_error("invalid type for '#{key}' (found #{code.klass}, expected #{type[:class]})")
            end
          end

          if res == []
            method = "new_instance(#{class_name.inspect})"
          else
            method = "new_instance(#{class_name.inspect}, #{res.join(', ')})"
          end

          expand_with_finder(
            :method     => method,
            :class      => klass,
            :nil        => true,
            :new_record => true,
            :new_keys   => keys
          )
        end

        def r_errors
          # Very basic for the moment
          "<%= error_messages_for(#{node.form_name}, :object => #{node}) %>"
        end

        def make_input(form_helper, name, type, textarea = false)
          if type == Time
            "<%= date_box(#{node}, :#{name}) %>"
          elsif textarea
            "<%= #{form_helper}.text_area :#{name}, :id => '#{node.dom_prefix}_#{name}' %>"
          else
            "<%= #{form_helper}.text_field :#{name}, :id => '#{node.dom_prefix}_#{name}' %>"
          end
        end

        def make_form
          if !@context[:make_form] || node.list_context? || @context[:form_helper].blank?
            return super
          else
            form_helper = @context[:form_helper]
          end

          if %W{link show}.include?(method) || method == 'zazen' || (name = method[/zazen\(\s*(\w+)\s*\)/,1])
            name ||= @params[:attr] || @params[:date] || 'title'
            textarea = method =~ /zazen/
          elsif type = node.klass.safe_method_type([method])
            name = method
          end

          if name
            type ||= node.klass.safe_method_type([name])
            # do we have a property ?
            if type && (node.real_class.column_names.include?(name) || node.klass.column_names.include?(name))
              # create an input field
              out make_input(form_helper, name, type[:class], textarea)
            else
              # ignore
              out ''
            end
          else
            super
          end
        end

        def form_options
          opts = super

          dom_name = node.dom_prefix
          opts[:form_helper] = 'f'

          if upd = @params[:update]
            if target = find_target(upd)
              @context[:template_url] = target.template_url
            end
          end

          if template_url = @context[:template_url]
            # Ajax

            if edit_or_cancel = descendant('cancel') || descendant('edit')
              if cancel_text = edit_or_cancel.params[:cancel] ||
                (edit_or_cancel.method == 'cancel' && edit_or_cancel.params[:text])
              elsif cancel_text = edit_or_cancel.params[:tcancel] ||
                (edit_or_cancel.method == 'cancel' && edit_or_cancel.params[:t])
                cancel_text = RubyLess.translate(self, "t(%Q{#{cancel_text}})")
                if cancel_text.literal
                  cancel_text = cancel_text.literal
                else
                  cancel_text_ruby = cancel_text
                  cancel_text = "<%= #{cancel_text} %>"
                end
              end
              cancel_pre  = ''
              cancel_post = ''
            else
              cancel_pre  = "<p class='btn_x'>"
              cancel_post = "</p>"
            end

            cancel_text ||= _('btn_x')
            cancel_text_ruby ||= cancel_text.inspect

            if @context[:in_add]
              # Inline form used to create new elements: set values to '' and 'parent_id' from context
              opts[:id]          = "#{node.dom_prefix}_form"
              opts[:form_tag]    = "<% remote_form_for(:#{node.form_name}, #{node}, :url => #{node.form_name.pluralize}_path, :html => {:id => \"#{dom_name}_form_t\"}) do |f| %>"
              opts[:form_cancel] = "#{cancel_pre}<a href='#' onclick='[\"#{dom_name}_add\", \"#{dom_name}_form\"].each(Element.toggle);return false;'>#{cancel_text}</a>#{cancel_post}\n"
            else
              # Saved form
              opts[:id]          = "<%= ndom_id(#{node}) %>"

              opts[:form_tag]    = %Q{
<% remote_form_for(:#{node.form_name}, #{node}, :url => #{node}.new_record? ? #{node.form_name.pluralize}_path : #{node.form_name}_path(#{node}.zip), :html => {:method => #{node}.new_record? ? :post : :put, :id => \"\#{ndom_id(#{node})}_form_t\"}) do |f| %>
}

              opts[:form_cancel] = %Q{
<% if #{node}.new_record? %>
  #{cancel_pre}<a href='#' onclick='[\"<%= params[:dom_id] %>_add\", \"<%= params[:dom_id] %>_form\"].each(Element.toggle);return false;'>#{cancel_text}</a>#{cancel_post}
<% else %>
  #{cancel_pre}<%= link_to_remote(#{cancel_text_ruby}, :url => #{node.form_name}_path(#{node}.zip) + \"/zafu?t_url=#{CGI.escape(template_url)}&dom_id=\#{params[:dom_id]}#{@context[:has_link_id] ? "&link_id=\#{#{node}.link_id}" : ''}\", :method => :get) %>#{cancel_post}
<% end %>
}
            end
          else
            # no ajax
            if descendants('errors')
              error_messages = ''
            else
              error_messages = r_errors + "\n"
            end

            opts[:form_tag]    = %Q{
<% form_for(:#{node.form_name}, #{node}, :url => #{node}.new_record? ? #{node.form_name.pluralize}_path : #{node.form_name}_path(#{node}.zip), :html => {:method => #{node}.new_record? ? :post : :put, :id => \"\#{ndom_id(#{node})}_form_t\"}) do |f| %>
#{error_messages}}
          end

          opts
        end

        def form_hidden_fields(opts)
          hidden_fields = super
          add_params = @context[:add] ? @context[:add].params : {}
          set_fields = []
          @markup.params[:class] ||= 'form'

          (descendants('input') + descendants('select')).each do |tag|
            set_fields << "#{node.form_name}[#{tag.params[:name]}]"
          end

          if template_url = @context[:template_url]
            # Ajax

            if (descendants('input') || []).detect {|elem| elem.params[:type] == 'submit'}
              # has submit
            else
              # Hidden submit for Firefox compatibility
              hidden_fields['submit'] = ["<input type='submit'/>"]
            end

            hidden_fields['link_id'] = "<%= #{node}.link_id %>" if @context[:has_link_id] && node.will_be?(Node)

            if upd = @params[:update]
              if target = find_target(upd)
                hidden_fields['u_url']   = target.template_url
                hidden_fields['udom_id'] = upd # target.node.dom_prefix ? (but target.node is not set yet...)
                # hidden_fields['u_id']    = "<%= #{@context[:parent_node]}.zip %>" if @context[:in_add]
                hidden_fields['s']       = "<%= start_node_zip %>"
              end
            # elsif (block = ancestor('block')) && node.will_be?(DataEntry)
            #   # updates template url
            #   hidden_fields['u_url']   = block.template_url
            #   hidden_fields['udom_id'] = block.erb_dom_id
            end

            hidden_fields['t_url'] = template_url


            # t_id = node zip to use when rendering partial (enable back when we have a use case).
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
              if node.opts[:new_record] || @context[:saved_template]
                hidden_fields['node[parent_id]'] = "<%= #{@context[:in_add] ? "#{node.up.up}.zip" : "#{node}.parent_zip"} %>"
              end
            elsif node.will_be?(Comment)
              # FIXME: the "... || '@node'" is a hack and I don't understand why it's needed...
              hidden_fields['node_id'] = "<%= #{node.up || '@node'}.zip %>"
            elsif node.will_be?(DataEntry)
              return parser_error("Missing :data_root in context (internal error)") unless data_root = @context[:data_root]
              hidden_fields["data_entry[#{data_root}_id]"] = "<%= #{@context[:in_add] ? node(Node) : "#{node}.#{data_root}"}.zip %>"
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

            if node.will_be?(Node)
              # Nested contexts:
              # 1. @node
              # 2. var1 = @node.children
              # 3. var1_new = Node.new
              if node.opts[:new_record]
                hidden_fields['node[parent_id]'] = "<%= #{node.up}.zip %>"
              end
            end
            cancel = "" # link to normal node ?
          end

          if node.will_be?(Node) && (@params[:klass] || @context[:klass])
            hidden_fields['node[klass]'] = @params[:klass] || @context[:klass]
          end

          if node.will_be?(Node) && @params[:mode]
            hidden_fields['mode'] = @params[:mode]
          end

          hidden_fields['node[v_status]'] = Zena::Status[:pub].to_s if add_params[:publish] || auto_publish_param || @context[:publish_after_save]

          # All default values set in the <r:new> field should at least appear as hidden fields
          if new_keys = node.opts[:new_keys]
            input_keys = (
              (descendants('input') || []).map {|e| e.params[:name]} +
              hidden_fields.keys.map do |e|
                if e =~ /.*\[(.*)\]/
                  $1.to_sym
                else
                  nil
                end
              end
            ).compact.uniq

            new_keys.each do |key, value|
              next if input_keys.include?(key)
              hidden_fields["node[#{key}]"] = "<%= #{node}.#{value} %>"
            end
          end

          # Read @params
          @params.each do |key, value|
            next if [:klass, :done].include?(key)
            code = ::RubyLess.translate_string(self, value)
            if code.literal.kind_of?(String)
              hidden_fields[key] = "#{code.literal}"
            else
              hidden_fields[key] = "<%= #{code} %>"
            end
          end

          hidden_fields.reject! do |k,v|
            # There is an explicit <input> field for this key, remove hidden value
            set_fields.include?(k)
          end

          hidden_fields
        end

        def r_textarea
          html_attributes, attribute = get_input_params()
          erb_attr = html_attributes.delete(:erb_attr)
          value = html_attributes.delete(:value)

          return parser_error('Missing name.') unless attribute || html_attributes[:name]

          @markup.tag = 'textarea'
          @markup.set_dyn_params(html_attributes)

          if @blocks == [] || @blocks == ['']
            if @context[:in_add]
              value = ''
            end
          else
            value = expand_with
          end

          res = @markup.wrap(value)

          extract_label(res, attribute || erb_attr)
        end

        # <r:select name='klass' root_class='...'/>
        # <r:select name='parent_id' nodes='projects in site'/>
        # <r:select name='parent_id' values='a,b,c'/>
        # TODO: optimization (avoid loading full AR to only use [id, name])
        def r_select
          html_attributes, attribute = get_input_params()
          erb_attr = html_attributes.delete(:erb_attr)
          # TEMPORARY HACK UNTIL WE FIX get_input_params to return a single hash with
          # {:html => { prepared html attributes }, :raw => {:value => '..', :name => '..', :param => '..'}}
          if param = @params[:param]
            selected  = "params[#{param.to_sym.inspect}].to_s"
            attribute = param
          else
            return parser_error("missing name") unless attribute

            if value = @params[:selected]
              selected = ::RubyLess.translate_string(self, value)
            elsif @context[:in_filter]
              selected = "params[#{attribute.to_sym.inspect}].to_s"
            elsif %w{parent_id}.include?(attribute)
              selected = "#{node}.parent_zip.to_s"
            elsif attribute == 'copy_id'
              selected = 'nil'
            elsif attribute =~ /^(.*)_id$/
              # relation
              selected = "#{node}.rel[#{$1.inspect}].other_zip.to_s"
            elsif type = node.klass.safe_method_type([attribute])
              selected = "#{node}.#{type[:method]}.to_s"
            else
              # ???
              selected = "#{node}.prop[#{attribute.inspect}].to_s"
            end
          end

          html_id = html_attributes[:id] ? " id='#{html_attributes[:id]}'" : ''
          if @context[:in_filter] || @params[:param]
            select_tag = "<select#{html_id} name='#{attribute}'>"
          else
            select_tag = "<select#{html_id} name='#{node.form_name}[#{attribute}]'>"
          end

          res = if klass = @params[:root_class]
            class_opts = ''
            class_opts << ", :without => #{@params[:without].inspect}" if @params[:without]
            # do not use 'selected' if the node is not new
            "#{select_tag}<%= options_for_select(Node.classes_for_form(:class => #{klass.inspect}#{class_opts}, :class_attr => #{(@params[:attr] || 'name').inspect}), (#{node}.new_record? ? #{selected} : #{node}.klass)) %></select>"
          elsif @params[:type] == 'time_zone'
            # <r:select name='d_tz' type='time_zone'/>
            "#{select_tag}<%= options_for_select(TZInfo::Timezone.all_identifiers, #{selected}) %></select>"
          elsif options_list = get_options_for_select
            "#{select_tag}<%= options_for_select(#{options_list}, #{selected}) %></select>"
          else
            parser_error("missing 'nodes', 'root_class' or 'values'")
          end

          extract_label(res, attribute || erb_attr)
        end


        def r_input
          html_attributes, attribute = get_input_params()
          erb_attr = html_attributes.delete(:erb_attr)
          # TODO: get attribute type from get_input_params
          res = case @params[:type]
          when 'select' # FIXME: why is this only for classes ?
            out parser_error("please use [select] here")
            r_select
          when 'date_box', 'date'
            return parser_error("date_box without name") unless attribute
            code = ::RubyLess.translate(self, "this.#{attribute}")
            value = @context[:in_add] ? "''" : code
            html_params = [':size => 15']
            [:style, :class, :onclick, :size, :time].each do |key|
              html_params << ":#{key} => #{@params[key].inspect}" if @params[key]
            end
            html_params << ":id=>\"#{dom_id}_#{attribute}\"" if @context[:dom_prefix]
            "<%= date_box(#{node}, #{attribute.inspect}, :value => #{value}, #{html_params.join(', ')}) %>"
          when 'id'
            return parser_error("select id without name") unless attribute
            name = "#{attribute}_id" unless attribute[-3..-1] == '_id'
            input_id = @context[:erb_dom_id] ? ", :input_id =>\"#{erb_dom_id}_#{attribute}\"" : ''
            "<%= select_id('#{node.form_name}', #{attribute.inspect}#{input_id}) %>"
          when 'time_zone'
            out parser_error("please use [select] here")
            r_select
          when 'submit'
            @markup.tag = 'input'
            @markup.set_param(:type, @params[:type])
            @markup.set_param(:text, @params[:text]) if @params[:text]
            @markup.set_params(html_attributes)
            wrap('')
          else
            # 'text', 'hidden', ...
            return parser_error('Missing name.') unless attribute || html_attributes[:name]
            @markup.tag = 'input'
            @markup.set_param(:type, @params[:type] || 'text')

            checked = html_attributes.delete(:checked)
            @markup.set_dyn_params(html_attributes)
            @markup.append_attribute checked if checked
            wrap('')
          end

          extract_label(res, attribute || erb_attr)
        end

        # <r:checkbox role='collaborator_for' values='projects' in='site'/>"
        def r_checkbox
          nodes  = @params[:nodes]
          values = @params[:values]
          return parser_error("missing 'nodes' or 'values'") unless nodes || values

          if values
            return parser_error("missing attribute 'name'") unless name = @params[:name]
            # parse literal values
            opts = [":name => #{name.inspect}", ":list => #{values.split(',').map(&:strip).inspect}"]
            if show_values = @params[:show]
              opts << ":show => #{show_values.split(',').map(&:strip).inspect}"
            elsif show_values = @params[:tshow]
              opts << ":show => #{translate_list(show_values).inspect}"
            end
            meth = RubyLess.translate(self, "this.#{name}")
            opts << ":selected => #{meth}"
            attribute = name
            res = "<%= make_checkbox(#{node}, #{opts.join(', ')}) %>"
          else
            if name = @params[:name]
              if name =~ /(.*)_ids?\Z/
                role = $1
              else
                role = name
              end
            else
              role = @params[:role]
            end
            return parser_error("missing 'role'") unless role
            # nodes
            meth = role.singularize

            if nodes =~ /^\d+\s*($|,)/
              values = nodes.split(',').map{|v| v.to_i}
              finder = "secure(Node) { Node.all(:conditions => 'zip IN (#{values.join(',')})') }"
            else
              return unless finder = build_finder(:all, nodes, @params)
              return parser_error("invalid class (#{finder[:class]})") unless finder[:class].first <= Node
              finder = finder[:method]
            end

            attribute = @params[:attr] || 'title'
            res = "<%= make_checkbox(#{node}, :list => #{finder}, :role => #{meth.inspect}, :attr => #{attribute.inspect}) %>"
          end

          extract_label(res, attribute)
        end

        alias r_radio r_checkbox

        # transform a 'show' tag into an input field.
        #def make_input(params = @params)
        #  input, attribute = get_input_params(params)
        #  return parser_error("missing 'name'") unless attribute
        #  return '' if attribute == 'parent_id' # set with 'r_form'
        #  return '' if ['url','path'].include?(attribute) # cannot be set with a form
        #  if params[:date]
        #  input_id = @context[:dom_prefix] ? ", :id=>\"#{dom_id}_#{attribute}\"" : ''
        #    return "<%= date_box(#{node}, #{params[:date].inspect}#{input_id}) %>"
        #  end
        #  input_id = node.dom_prefix ? " id='#{node.dom_prefix}_#{attribute}'" : ''
        #  "<input type='#{params[:type] || 'text'}'#{input_id} name='#{input[:name]}' value='#{input[:value]}'/>"
        #end
        #

        # Parse params to extract everything that is relevant to building input fields.
        # TODO: refactor and pass the @markup so that attributes are added directly
        # TODO: get attribute type in get_input_params (safe_method_type)
        def get_input_params(params = @params)
          res = Zafu::OrderedHash.new
          if name = (params[:param] || params[:name] || params[:date])
            res[:name] = name
            unless params[:param]
              # build name
              if res[:name] =~ /\A([\w_]+)\[(.*?)\]/
                # Sub attributes are used with tags or might be used for other features. It
                # enables things like 'tagged[foo]'
                attribute, sub_attr = $1, $2
              else
                attribute = res[:name]
              end

              if sub_attr
                res[:name] = "#{node.form_name}[#{attribute}][#{sub_attr}]"
              else
                res[:name] = "#{node.form_name}[#{attribute}]"
              end
            end

            if sub_attr
              type = node.klass.safe_method_type([attribute])
              if sub_attr_ruby = RubyLess.translate(self, %Q{this.#{attribute}[#{sub_attr.inspect}]})
                res[:value] = "<%= fquote #{sub_attr_ruby} %>"
              end
            else
              if value = params[:value]
                # On refactor, use append_markup_attr(markup, key, value)
                value = RubyLess.translate_string(self, value)

                if value.literal
                  res[:value] = form_quote(value.literal.to_s)
                else
                  res[:value] = "<%= fquote #{value} %>"
                end
              elsif params[:param]
                if name =~ /^[a-z_]+$/
                  res[:value] = "<%= fquote params[:#{name}] %>"
                else
                  res[:value] = "<%= fquote param_value(#{name.inspect}) %>"
                end
              elsif attribute && type = node.klass.safe_method_type([attribute])
                res[:value] = "<%= fquote #{node}.#{type[:method]} %>"
              end
            end

            if sub_attr && params[:type] == 'checkbox' && !params[:value]
              # Special case when we have a sub_attribute: default value for "tagged[foobar]" is "foobar"
              params[:value] = sub_attr
            end

            #if @context[:in_add]
            #  res[:value] = (params[:value] || params[:set_value]) ? ["'#{ helper.fquote(params[:value])}'"] : ["''"]
            #elsif @context[:in_filter]
            #  res[:value] = attribute ? ["'<%= fquote params[#{attribute.to_sym.inspect}] %>'"] : ["''"]
            #elsif params[:value]
            #  res[:value] = ["'#{ helper.fquote(params[:value])}'"]
            #else
            #  if nattr != 'nil'
            #    res[:value] = ["'<%= fquote #{nattr} %>'"]
            #  else
            #    res[:value] = ["''"]
            #  end
            #end
          elsif node.will_be?(Column)
            res[:erb_attr] = "<%= #{node}.name %>"
            res[:name]  = "node[<%= #{node}.name %>]"
            res[:value] = "<%= fquote #{node(Node)}.prop[#{node}.name] %>"
          end

          if node.dom_prefix && !params[:param]
            res[:id]   = "#{node.dom_prefix}_#{attribute}"
          else
            res[:id]   = params[:id] if params[:id]
          end

          if params[:type] == 'checkbox' && sub_attr_ruby
            if value = params[:value]
              res[:checked] = "<%= #{sub_attr_ruby} == #{value.inspect} ? \" checked='checked'\" : '' %>"
            else
              res[:checked] = "<%= #{sub_attr_ruby}.blank? ? '' : \" checked='checked'\" %>"
            end
          end

          params.each do |k, v|
            next unless [:size, :style, :class].include?(k)
            res[k] = params[k]
          end

          return [res, attribute]
        end

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

        def r_crop
          return parser_error("Invalid node type #{node.klass} (should be an Image).") unless node.will_be?(Image)
          @markup.tag ||= 'div'
          node.dom_prefix = dom_name
          @markup.set_id(node.dom_id(:list => false))
          dom = node.dom_id(:erb => false, :list => false)
          out %Q{<%= render :partial => 'documents/crop', :locals => {:node => #{node(Node)}, :img_id => "img#{dom}"} %>}
          out %Q{<% js_data << %Q{new Zena.Div_editor("img#{dom}", 'posx', 'posy', 'width', 'height', \#{#{node}.width / #{node}.width(Iformat['edit']).to_f}, Element.viewportOffset('#{dom}').left, Element.viewportOffset('#{dom}').top);} %>}
        end

        protected

          # Get current attribute in forms
          def node_attribute(attribute)
            node_attribute = ::RubyLess.translate(node.klass, attribute)
            "#{node}.#{node_attribute}"
          rescue ::RubyLess::NoMethodError
            if node.will_be?(Node)
              "#{node}.prop[#{attribute.inspect}]"
            else
              'nil'
            end
          end

          # Set auto publish parameter value
          def auto_publish_param(in_string = false)
            if in_string
              %w{true force}.include?(@params[:publish]) ? "&publish=#{@params[:publish]}" : ''
            else
              @params[:publish]
            end
          end

          # Return options for [select] tag.
          def get_options_for_select
            if nodes = @params[:nodes]
              # TODO: dry with r_checkbox
              klass = Node
              if nodes =~ /^\d+\s*($|,)/
                # ids
                # TODO: optimization generate the full query instead of using secure.
                nodes = nodes.split(',').map{|v| v.to_i}
                nodes = "(secure(Node) { Node.find(:all, :conditions => 'zip IN (#{nodes.join(',')})') })"
              else
                # relation
                begin
                  finder = build_finder(:all, nodes, @params)
                  klass  = finder[:class].first
                rescue ::QueryBuilder::Error => err
                  out parser_error(err.message)
                  return nil
                end

                return parser_error("invalid class (#{klass})") unless klass <= Node
                nodes = finder[:method]
              end

              set_attr  = ::RubyLess.translate(klass, @params[:attr] || 'id')
              show_attr = ::RubyLess.translate(klass, @params[:show] || 'title')

              options_list = "[['','']] + (#{nodes} || []).map{|r| [r.#{show_attr}, r.#{set_attr}.to_s]}"
            elsif values = @params[:values]
              options_list = values.split(',').map(&:strip)

              if show = @params[:show]
                show_values = show.split(',').map(&:strip)
              elsif show = @params[:tshow]
                show_values = translate_list(show)
              end

              if show_values
                options_list.each_index do |i|
                  options_list[i] = [show_values[i], options_list[i]]
                end
              end
              options_list.inspect
            elsif code = @params[:eval]
              ruby = ::RubyLess.translate(self, code)
              if !ruby.klass.kind_of?(Array)
                return parser_error("invalid eval: should return an Array (found #{ruby.klass})")
              end

              if ruby.klass.first <= String
                # ok
                ruby
              else
                return parser_error("cannot extract values from eval (not a String list: [#{ruby.klass.first}])")
              end
            end
          end

          # Return the default field that will receive focus on form display.
          def default_focus_field
            if (input_fields = descendants('input')) != []
              input_fields.first.params[:name]
            elsif (show_fields = descendants('show')) != []
              show_fields.first.params[:attr]
            elsif node.will_be?(Node)
              'title'
            else
              'text'
            end
          end
      end # ZafuMethods
    end # Forms
  end # Use
end # Zena