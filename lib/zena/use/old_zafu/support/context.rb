module Zafu
  module Support
    module Context

      # use all other tags as rubyless or relations
      def r_unknown
        context = change_context(@method)
        open_context(context)
      end


      # Enter a new context (<r:context find='all' select='pages'>). This is the same as '<r:pages>...</r:pages>'). It is
      # considered better style to use '<r:pages>...</r:pages>' instead of the more general '<r:context>' because the tags
      # give a clue on the context at start and end. Another way to open a context is the 'do' syntax: "<div do='pages'>...</div>".
      # FIXME: 'else' clause has been removed, find a solution to put it back.
      def r_context
        # DRY ! (build_finder_for, block)
        return parser_error("missing 'select' parameter") unless method = @params[:select]
        context = change_context(method, :skip_rubyless => true)
        open_context(context)

        #context = RubyLess::SafeClass.safe_method_type_for(node_class, [method]) if use_rubyless
        #if context && @params.keys == [:select]
        #  open_context("#{node}.#{context[:method]}", context.dup)
        #elsif node.will_be?(Node)
        #  count   = ['first','all','count'].include?(@params[:find]) ? @params[:find].to_sym : nil
        #  count ||= Node.plural_relation?(method) ? :all : :first
        #  finder, klass, query = build_finder_for(count, method, @params)
        #  return unless finder
        #  if node.will_be?(Node) && !klass.ancestors.include?(Node)
        #    # moving out of node: store last Node
        #    @context[:previous_node] = node
        #  end
        #  if count == :all
        #    # plural
        #    do_list( finder, query, :node_class => klass)
        #  # elsif count == :count
        #  #   "<%= #{build_finder_for(count, method, @params)} %>"
        #  else
        #    # singular
        #    do_var(  finder, :node_class => klass)
        #  end
        #else
        #  "unknown relation (#{method}) for #{node_class} class"
        #end
      end

      # Group elements in a list. Use :order to specify order.
      def r_group
        return parser_error("cannot be used outside of a list") unless list_var = @context[:list]
        return parser_error("missing 'by' clause") unless key = @params[:by]

        sort_key = @params[:sort] || 'name'
        if node.will_be?(DataEntry) && DataEntry::NodeLinkSymbols.include?(key.to_sym)
          key = "#{key}_id"
          sort_block = "{|e| (e.#{key} || {})[#{sort_key.to_sym.inspect}]}"
          group_array = "group_array(#{list_var}) {|e| e.#{key}}"
        elsif node.will_be?(Node)
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

        def node.will_be?(ancestor)
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

        def open_context(context)
          return nil unless context
          klass = context.delete(:class)
          if klass.kind_of?(Class) && klass.ancestors.include?(String) && (@blocks.empty? || @blocks.size == 1 && @blocks[0].kind_of?(String))
            out "<%= #{context[:method]} %>"
            return
          end
          # hack to store last 'Node' context until we fix node(Node) stuff:
          previous_node = node.will_be?(Node) ? node : @context[:previous_node]
          if klass.kind_of?(Array)
            # plural
            do_list( context[:method], context.merge(:node_class => klass[0], :previous_node => previous_node) )
          else
            # singular
            do_var(  context[:method], context.merge(:node_class => klass, :previous_node => previous_node) )
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

    end # Context
  end # Support
end # Zafu