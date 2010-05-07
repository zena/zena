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
          elsif node.will_be?(Node)
            field = 'title'
          else
            field = 'text'
          end
        end
    end # Forms
  end # Support
end # Zafu