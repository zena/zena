module Zafu
  module Support
    module Context

      # Group elements in a list. Use :order to specify order.
      def r_group
        return parser_error("cannot be used outside of a list") unless list_var = @context[:list]
        return parser_error("missing 'by' clause") unless key = @params[:by]

        sort_key = @params[:sort] || 'name'
        if node_kind_of?(DataEntry) && DataEntry::NodeLinkSymbols.include?(key.to_sym)
          key = "#{key}_id"
          sort_block = "{|e| (e.#{key} || {})[#{sort_key.to_sym.inspect}]}"
          group_array = "group_array(#{list_var}) {|e| e.#{key}}"
        elsif node_kind_of?(Node)
          if ['project', 'parent', 'section'].include?(key)
            sort_block  = "{|e| (e.#{key} || {})[#{sort_key.to_sym.inspect}]}"
            group_array = "group_array(#{list_var}) {|e| e.#{key}_id}"
          end
        end

        group_array ||= "group_array(#{list_var}) {|e| #{node_attribute(key, :node => 'e')}}"

        if sort_block
          out "<% grp_#{list_var} = sort_array(#{group_array}) #{sort_block} -%>"
        else
          out "<% grp_#{list_var} = #{group_array} -%>"
        end

        if descendant('each_group')
          out expand_with(:group => "grp_#{list_var}")
        else
          @context[:group] = "grp_#{list_var}"
          r_each_group
        end
      end

      protected

        # find the current node name in the context
        def node(klass = self.node_class)
          if klass == self.node_class
            (@context[:saved_template] && @context[:main_node]) ? "@#{base_class.to_s.underscore}" : (@context[:node] || '@node')
          elsif klass == Node
            @context[:previous_node] || '@node'
          else
            # ?
            out parser_error("could not find node_name for #{klass} (current class is #{node_class})")
            '@node'
          end
        end

        def var
          return @var if @var
          if node =~ /^var(\d+)$/
            @var = "var#{$1.to_i + 1}"
          else
            @var = "var1"
          end
        end

        def list_var
          return @list_var if @list_var
          if (list || "") =~ /^list(\d+)$/
            @list_var = "list#{$1.to_i + 1}"
          else
            @list_var = "list1"
          end
        end

        # Class of the current 'node' object (can be Version, Comment, Node, DataEntry, etc)
        def node_class
          @context[:node_class] || Node
        end

        def node_kind_of?(ancestor)
          node_class.ancestors.include?(ancestor)
        end

        def list
          @context[:list]
        end

        def helper
          @options[:helper]
        end

        # Return parameter value accessor
        def get_param(key)
          "params[:#{key}]"
        end

        def find_stored(klass, key)
          if "#{klass}_#{key}" == "Node_start_node"
            # main node before ajax stuff (the one in browser url)
            "start_node"
          else
            @context["#{klass}_#{key}"]
          end
        end

        def set_stored(klass, key, obj)
          @context["#{klass}_#{key}"] = obj
        end

        def open_context(finder, context)
          klass = context[:node_class]
          # hack to store last 'Node' context until we fix node(Node) stuff:
          previous_node = node_kind_of?(Node) ? node : @context[:previous_node]
          if klass.kind_of?(Array)
            # plural
            do_list( finder, nil, context.merge(:node_class => klass[0], :previous_node => previous_node) )
          else
            # singular
            do_var(  finder, context.merge(:previous_node => previous_node) )
          end
        end

        def do_var(var_finder=nil, opts={})
          clear_dom_scope
          if var_finder == 'nil'
            out "<% if nil -%>"
          elsif var_finder
            out "<% if #{var} = #{var_finder} -%>"
          end

          if descendant('unlink')
            @html_tag ||= 'div'
            new_dom_scope
            @html_tag_params[:id] = erb_dom_id
          end

          res = expand_with(opts.merge(:node=>var, :in_if => false))

          if var_finder
            res += expand_with(opts.merge(:in_if => true, :only => ['else', 'elsif'], :html_tag_params => @html_tag_params, :html_tag => @html_tag))
          end
          out render_html_tag(res)
          out "<% end -%>" if var_finder
        end

        def do_list(list_finder, query = nil, opts={})
          clear_dom_scope

          @context.merge!(opts)          # pass options from 'zafu_known_contexts' to @context

          if (each_block = descendant('each')) && (each_block.descendant('edit') || descendant('add') || descendant('add_document') || (descendant('swap') && descendant('swap').parent.method != 'block') || ['block', 'drop'].include?(each_block.single_child_method))
            new_dom_scope
            # ajax, build template. We could merge the following code with 'r_block'.
            add_block  = descendant('add')
            form_block = descendant('form') || each_block

            @context[:need_link_id] = form_block.need_link_id

            out "<% if (#{list_var} = #{list_finder}) || (#{node}.#{node_kind_of?(Comment) ? "can_comment?" : "can_write?"} && #{list_var}=[]) -%>"
            if query && (pagination_key = query.pagination_key)
              out "<% set_#{pagination_key}_nodes = #{query.finder(:count)}; set_#{pagination_key}_count = (set_#{pagination_key}_nodes / #{query.page_size.to_f}).ceil; set_#{pagination_key} = [1,params[:#{pagination_key}].to_i].max -%>"
              @context[:paginate] = pagination_key
              @context[:vars] ||= []
              @context[:vars] << "#{pagination_key}_nodes"
              @context[:vars] << "#{pagination_key}_count"
              @context[:vars] << pagination_key
            end

            # should we publish ?
            publish_after_save ||= form_block ? form_block.params[:publish] : nil
            publish_after_save ||= descendant('edit') ? descendant('edit').params[:publish] : nil

            # class name for create form
            klass       = add_block  ? add_block.params[:klass]  : nil
            klass     ||= form_block ? form_block.params[:klass] : nil

            # INLINE ==========
            # 'r_add' needs the form when rendering. Send with :form.
            out render_html_tag(expand_with(:list=>list_var, :in_if => false, :form=>form_block, :publish_after_save => publish_after_save, :ignore => ['form'], :klass => klass))
            out expand_with(:in_if=>true, :only=>['elsif', 'else'], :html_tag => @html_tag, :html_tag_params => @html_tag_params)
            out "<% end -%>"

            # SAVED TEMPLATE ========
            template      = expand_block(each_block, :list=>false, :klass => klass, :saved_template => true)
            out helper.save_erb_to_url(template, template_url)

            # FORM ============
            if each_block != form_block
              form = expand_block(form_block, :klass => klass, :add=>add_block, :publish_after_save => publish_after_save, :saved_template => true)
            else
              form = expand_block(form_block, :klass => klass, :add=>add_block, :make_form=>true, :publish_after_save => publish_after_save, :saved_template => true)
            end
            out helper.save_erb_to_url(form, form_url)
          else
            # no form, render, edit and add are not ajax
            if descendant('add') || descendant('add_document')
              out "<% if (#{list_var} = #{list_finder}) || (#{node}.#{node_kind_of?(Comment) ? "can_comment?" : "can_write?"} && #{list_var}=[]) -%>"
            elsif list_finder != 'nil'
              out "<% if #{list_var} = #{list_finder} -%>"
            else
              out "<% if nil -%>"
            end

            if query && (pagination_key = query.pagination_key)
              out "<% set_#{pagination_key}_nodes = #{query.finder(:count)}; set_#{pagination_key}_count = (set_#{pagination_key}_nodes / #{query.page_size.to_f}).ceil; set_#{pagination_key} = [1,params[:#{pagination_key}].to_i].max -%>"
              @context[:paginate] = pagination_key
              @context[:vars] ||= []
              @context[:vars] << "#{pagination_key}_nodes"
              @context[:vars] << "#{pagination_key}_count"
              @context[:vars] << "#{pagination_key}"
            end

            out render_html_tag(expand_with(:list=>list_var, :in_if => false))
            out expand_with(:in_if=>true, :only=>['elsif', 'else'], :html_tag => @html_tag, :html_tag_params => @html_tag_params)
            out "<% end -%>"
          end
        end
    end # Context
  end # Support
end # Zafu