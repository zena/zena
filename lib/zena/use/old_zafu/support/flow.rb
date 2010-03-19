module Zafu
  module Support
    module Flow

      def r_each_group
        return parser_error("must be used inside a group context") unless group = @context[:group]
        if join = @params[:join]
          join = join.gsub(/&lt;([^%])/, '<\1').gsub(/([^%])&gt;/, '\1>')
          out "<% #{group}.each_index do |#{list_var}_index| -%>"
          out "<%= #{list_var}=#{group}[#{list_var}_index]; #{var} = #{list_var}[0]; #{list_var}_index > 0 ? #{join.inspect} : '' %>"
        else
          out "<% #{group}.each do |#{list_var}|; #{var} = #{list_var}[0]; -%>"
        end
        out render_html_tag(expand_with(:group => nil, :list => list_var, :node => var, :scope_node => var))
        out "<% end -%>"
      end

      def r_each
        is_draggable = @params[:draggable] == 'true' || @params[:drag_handle]

        if descendant('edit') || descendant('unlink') || descendant('swap') || ['block', 'drop'].include?(single_child_method) || is_draggable
          id_hash = {:id => erb_dom_id}
        else
          id_hash = nil
        end


        if @context[:make_form]
          # use the elements inside 'each' loop to produce the edit form
          r_form
        elsif @context[:list]
          # normal rendering: not the start of a saved template
          if is_draggable || descendant('unlink')
            out "<% #{var}_dom_ids = [] -%>"
          end

          @params[:alt_class] ||= @html_tag_params.delete(:alt_class)
          # FIXME: add alt_reverse='true' to start counting from bottom (if order last on top...)
          if @params[:alt_class] || @params[:join]
            join = @params[:join] || ''
            join = join.gsub(/&lt;([^%])/, '<\1').gsub(/([^%])&gt;/, '\1>')
            out "<% #{var}_max_index = #{list}.size - 1 -%>" if @params[:alt_reverse]
            out "<% #{list}.each_with_index do |#{var},#{var}_index| -%>"

            if join_clause = @params[:join_if]
              set_stored(Node, 'prev', "#{var}_prev")
              cond = get_test_condition(var, :test=>join_clause)
              out "<%= #{var}_prev = #{list}[#{var}_index - 1]; (#{var}_index > 0 && #{cond}) ? #{join.inspect} : '' %>"
            else
              out "<%= #{var}_index > 0 ? #{join.inspect} : '' %>"
            end

            if alt_class = @params[:alt_class]
              alt_test = @params[:alt_reverse] == 'true' ? "(#{var}_max_index - #{var}_index) % 2 != 0" : "#{var}_index % 2 != 0"
              if html_class = @html_tag_params.delete(:class)
                html_append = " class='#{html_class}<%= #{alt_test} ? #{(' ' + alt_class).inspect} : '' %>'"
              else
                html_append = "<%= #{alt_test} ? ' class=#{alt_class.inspect}' : '' %>"
              end
            else
              html_append = nil
            end
          else
            out "<% #{list}.each do |#{var}| -%>"
            html_append = nil
          end

          if is_draggable
            out "<% #{var}_dom_ids << \"#{dom_id}\" -%>"
          end

          out r_anchor(var) if @anchor_param # insert anchor inside the each loop
          @params[:anchor] = @anchor_param   # set back in case we double render
          @anchor_param = nil

          res, drag_handle = set_drag_handle_and_id(expand_with(:node => var, :scope_node => var), @params, id_hash)

          out render_html_tag(res, html_append)

          out "<% end -%>"

          if is_draggable
            if drag_handle
              out "<script type='text/javascript'>\n//<![CDATA[\n<%= #{var}_dom_ids.inspect %>.each(function(dom_id, index) {
                  new Draggable(dom_id, {ghosting:true, revert:true, handle:$(dom_id).select('.#{drag_handle}')[0]});
              });\n//]]>\n</script>"
            else
              out "<script type='text/javascript'>\n//<![CDATA[\n<%= #{var}_dom_ids.inspect %>.each(Zena.draggable)\n//]]>\n</script>"
            end
          end

        elsif @context[:saved_template]
          # render to start a saved template
          res, drag_handle = set_drag_handle_and_id(expand_with(:scope_node => node), @params, id_hash)

          out render_html_tag(res)

          if is_draggable
            if drag_handle
              out "<script type='text/javascript'>\n//<![CDATA[\nnew Draggable('#{erb_dom_id}', {ghosting:true, revert:true, handle:$('#{erb_dom_id}').select('.#{drag_handle}')[0]});\n//]]>\n</script>"
            else
              out "<script type='text/javascript'>\n//<![CDATA[\nZena.draggable('#{erb_dom_id}')\n//]]>\n</script>"
            end
          end
        else
          # TODO: make a single list ?
          @context[:list] = "[#{node}]"
          r_each
        end
      end

      def r_case
        out "<% if false -%>"
        out expand_with(:in_if=>true, :only=>['when', 'else'], :html_tag => @html_tag, :html_tag_params => @html_tag_params)
        @html_tag_done = true
        out "<% end -%>"
      end

      # TODO: test
      def r_if
        cond = get_test_condition
        return parser_error("condition error") unless cond

        if cond == 'true'
          return expand_with(:in_if => false)
        elsif cond == 'false'
          if descendant('else') || descendant('elsif')
            out "<% if false -%>"
            out expand_with(:in_if=>true, :only=>['elsif', 'else'])
            out "<% end -%>"
            return
          else
            @html_tag_done = true
            return ''
          end
        end

        out "<% if #{cond} -%>"
        out render_html_tag(expand_with(:in_if=>false))
        out expand_with(:in_if=>true, :only=>['elsif', 'else'], :html_tag => @html_tag, :html_tag_params => @html_tag_params)
        out "<% end -%>"
      end

      def r_else
        if @context[:in_if]
          @html_tag = @context[:html_tag]
          @html_tag_params = @context[:html_tag_params] || {}
          out "<% elsif true -%>"
          if @params[:text]
            out render_html_tag(@params[:text])
          else
            out render_html_tag(expand_with(:in_if=>false, :only => nil)) # do not propagate :only from ancestor 'if' clause
          end
        else
          ""
        end
      end

      def r_elsif
        return '' unless @context[:in_if]
        @html_tag = @context[:html_tag]
        @html_tag_params = @context[:html_tag_params] || {}
        cond = get_test_condition
        return parser_error("condition error") unless cond
        out "<% elsif #{cond} -%>"
        out render_html_tag(expand_with(:in_if=>false, :only => nil)) # do not propagate :only from ancestor 'if' clause
      end

      def r_when
        r_elsif
      end

      protected

        # TODO: RUBYLESS
        def get_test_condition(node = self.node, params = @params)
          tests = []
          params.each do |k,v|
            if k.to_s =~ /^(or_|)([a-zA-Z_]+)(\d*)$/
              k = $2.to_sym
            end                                         #tagged undocumented
            if [:kind_of, :klass, :status, :lang, :can, :tagged, :node, :in, :visitor, :has].include?(k)
              tests << [k, v]
            elsif k == :test
              if v =~ /\s/
                tests << [:test, v]
              else
                tests << [:attribute, v]
              end
            end
          end


          tests.map! do |type,value|
            case type
            when :kind_of
            "#{node}.vkind_of?(#{value.inspect})"
            when :klass
              klass = begin Module::const_get(value) rescue "NilClass" end
              "#{node}.klass == #{value.inspect}"
            when :status
              "#{node}.version.status == #{Zena::Status[value.to_sym]}"
            when :tagged
              # TODO: undocumented: remove and use rubyless !
              "#{node}.tagged[#{value.inspect}]"
            when :lang
              "#{node}.version.lang == #{value.inspect}"
            when :can
              # TODO: test
              case value
              when 'write', 'edit'
                "#{node}.can_write?"
              when 'drive', 'publish'
                "#{node}.can_drive?"
              else
                nil
              end
            when :has
              case value
              when 'discussion'
                "#{node}.discussion"
              else
                nil
              end
            when :test
              parse_condition(value, node)
            when :attribute
              '!' + node_attribute(value, :node => node) + '.blank?'
            when :node
              if node.will_be?(Node)
                value, node_name = get_attribute_and_node(value)
                node_name ||= '@node'
                if value
                  case value
                  when 'main'
                    "#{node}[:id] == #{node_name}[:id]"
                  when 'start'
                    "#{node}[:zip] == (params[:s] || @node[:zip]).to_i"
                  when 'parent'
                    "#{node}[:id] == #{node_name}[:parent_id]"
                  when 'project'
                    "#{node}[:id] == #{node_name}[:project_id]"
                  when 'section'
                    "#{node}[:id] == #{node_name}[:section_id]"
                  when 'ancestor'
                    "#{node_name}.fullpath =~ /\\A\#{#{node}.fullpath}/"
                  else
                    if stored = find_stored(Node, value)
                      "#{node}[:id] == #{stored}[:id]"
                    else
                      nil
                    end
                  end
                else
                  # bad node_name
                  nil
                end
              else
                nil
              end
            when :in
              if @context["in_#{value}".to_sym] # FIXME: || ancestors.include?(value) ==> ancestors is a list of zafu tags, not a list of names !
                'true'
              else
                'false'
              end
            when :visitor
              if value == 'anon'
                "visitor.is_anon?"
              else
                nil
              end
            else
              nil
            end
          end.compact!
          tests == [] ? nil : tests.join(' || ')
        end

        def parse_condition_error(clause, rest, res)
          out parser_error("invalid clause #{clause.inspect} near \"#{res[-2..-1]}#{rest[0..1]}\"")
        end

        def parse_condition(clause, node_name)
          rest         = clause.strip
          types        = [:par_open, :value, :bool_op, :op, :par_close]
          allowed      = [:par_open, :value]
          par_count    = 0
          uses_bool_op = false
          segment      = []  # value op value
          after_value  = lambda { segment.size == 3 ? [:bool_op, :par_close] : [:op, :bool_op, :par_close]}
          res          = ""
          while rest != ''
            # puts rest.inspect
            if rest =~ /\A\s+/
              rest = rest[$&.size..-1]
            elsif rest[0..0] == '('
              unless allowed.include?(:par_open)
                parse_condition_error(clause, rest, res)
                return nil
              end
              res << '('
              rest = rest[1..-1]
              par_count += 1
            elsif rest[0..0] == ')'
              unless allowed.include?(:par_close)
                parse_condition_error(clause, rest, res)
                return nil
              end
              res << ')'
              rest = rest[1..-1]
              par_count -= 1
              if par_count < 0
                parse_condition_error(clause, rest, res)
                return nil
              end
              allowed = [:bool_op]
            elsif rest =~ /\A(lt|le|eq|ne|ge|gt)\s+/
              unless allowed.include?(:op)
                parse_condition_error(clause, rest, res)
                return nil
              end
              op = $1.strip
              rest = rest[op.size..-1]
              op = {'lt' => '<', 'le' => '<=', 'eq' => '==', 'ne' => '!=', 'ge' => '>=', 'gt' => '>'}[op]
              segment << [op, :op]
              allowed = [:value]
            elsif rest =~ /\A("|')([^\1]*?)\1/
              # string
              unless allowed.include?(:value)
                parse_condition_error(clause, rest, res)
                return nil
              end
              rest = rest[$&.size..-1]
              segment << [$2.inspect, :string]
              allowed = after_value.call
            elsif rest =~ /\A(-?\d+)/
              # number
              unless allowed.include?(:value)
                parse_condition_error(clause, rest, res)
                return nil
              end
              rest = rest[$&.size..-1]
              segment << [$1, :number]
              allowed = after_value.call
            elsif rest =~ /\A(and|or)/
              unless allowed.include?(:bool_op)
                parse_condition_error(clause, rest, res)
                return nil
              end
              uses_bool_op = true
              rest = rest[$&.size..-1]
              res << " #{$1} "
              allowed = [:par_open, :value]
            elsif rest =~ /\A([\w:\.\-]+)/
              # variable
              unless allowed.include?(:value)
                parse_condition_error(clause, rest, res)
                return nil
              end
              rest = rest[$&.size..-1]
              fld  = $1
              unless node_attr = node_attribute(fld, :node => node_name)
                parser_error("invalid field #{fld.inspect}")
                return nil
              end
              segment << [node_attr, :var]
              allowed = after_value.call
            else
              parse_condition_error(clause, rest, res)
              return nil
            end
            if segment.size == 3
              toi = (segment[1][0] =~ /(>|<)/ || (segment[0][1] == :number || segment[2][1] == :number))
              segment.map! do |part, type|
                if type == :var
                  toi ? "#{part}.to_i" : part
                elsif type == :string
                  toi ? part[1..-2].to_i : part
                else
                  part
                end
              end
              res << segment.join(" ")
              segment = []
            end
          end

          if par_count > 0
            parser_error("invalid clause #{clause.inspect}: missing closing ')'")
            return nil
          elsif allowed.include?(:value)
            parser_error("invalid clause #{clause.inspect}")
            return nil
          else
            return uses_bool_op ? "(#{res})" : res
          end
        end
    end # Flow
  end # Support
end # Zafu