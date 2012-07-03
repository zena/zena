module Zafu
  module Process
    # This module manages the change of contexts by opening (each) or moving into the NodeContext.
    # The '@context' holds many information on the current compilation environment. Inside this
    # context, the "node" context holds information on the type of "this" (first responder).
    module Context
      def r_each
        if node.list_context?
          if @params[:alt_class] || @params[:join]
            out "<% #{var}_max_index = #{node}.size - 1 %>" if @params[:alt_reverse]
            out "<% #{node}.each_with_index do |#{var},#{var}_index| %>"

            if join = @params[:join]
              join = RubyLess.translate_string(self, join)
              out "<%= #{var}_index > 0 ? #{join} : '' %>"
            end

            if alt_class = @params[:alt_class]
              alt_class = RubyLess.translate_string(self, alt_class)
              alt_test = @params[:alt_reverse] == 'true' ? "(#{var}_max_index - #{var}_index) % 2 != 0" : "#{var}_index % 2 != 0"

              alt_var = get_var_name('set_var', 'alt_class')
              set_context_var('set_var', 'alt_class', RubyLess::TypedString.new(alt_var, :class => String))
              out "<% #{alt_var} = #{alt_test} ? #{alt_class} : '' %>"

              if @markup.tag
                @markup.append_dyn_param(:class, "<%= #{alt_var} %>")
              else
                # Just declare 'alt_class'
              end
            end
          else
            out "<% #{node}.each do |#{var}| %>"
          end

          raw_dom_prefix = node.raw_dom_prefix

          with_context(:node => node.move_to(var, node.klass.first, :query => node.opts[:query])) do
            # We pass the :query option for RubyLess resolution by using the QueryBuilder finder

            steal_and_eval_html_params_for(@markup, @params)
            # The id set here should be used as prefix for sub-nodes to ensure uniqueness of generated DOM ids
            if node.list_context?
              # we are still in a list (example: previous context was [[Node]], current is [Node])
            else
              # Change dom_prefix if it isn't our own (inherited).
              node.dom_prefix = dom_name unless raw_dom_prefix
              node.propagate_dom_scope!

              if need_dom_id?
                @markup.set_id(node.dom_id)
              end
            end

            out wrap(expand_with)
          end
          out "<% end %>"
        else
          out expand_with
        end

        # We need to return true for Ajax 'make_form'
        true
      end

      def helper
        @context[:helper]
      end

      # Return true if we need to insert the dom id for this element. This method is overwritten in Ajax.
      def need_dom_id?
        false
      end

      # Return the node context for a given class (looks up into the hierarchy) or the
      # current node context if klass is nil.
      def node(klass = nil)
        return @context[:node] if !klass
        @context[:node].get(klass)
      end

      # Store some contextual value / variable inside a named group. This should be
      # used to avoid key clashes between different types of elements to store.
      def set_context_var(group, key, obj, context = @context)
        context["#{group}::#{key}"] = obj
      end

      # Retrieve a value from a given contextual group. The value must have been
      # previously set with 'set_context_var' somewhere in the hierarchy.
      def get_context_var(group, key, context = @context)
        context["#{group}::#{key}"]
      end

      # Return a new context without contextual variables.
      def context_without_vars
        context = @context.dup
        context.keys.each do |k|
          context.delete(k) if k.kind_of?(String)
        end
        context
      end

      # Expand blocks in a new context.
      # This method is partly overwriten in Ajax
      def expand_with_finder(finder)
        if finder[:nil]
          open_node_context(finder, :form => nil) do # do not propagate :form
            expand_if("#{var} = #{finder[:method]}", node.move_to(var, finder[:class], finder.merge(:nil => false)))
          end
        else
          res = ''
          res << "<% #{var} = #{finder[:method]} %>"
          open_node_context(finder, :node => node.move_to(var, finder[:class], finder), :form => nil) do
            res << wrap(expand_with)
          end
          res
        end
      end

      # def context_with_node(name, klass)
      #   context = @context.dup
      #   context[:node] = context[:node].move_to(name, klass)
      # end

      def var
        return @var if @var
        if node.name =~ /^var(\d+)$/
          @var = "var#{$1.to_i + 1}"
        else
          @var = "var1"
        end
      end

      # This method is called when we enter a new node context
      def node_context_vars(finder)
        # do nothing (this is a hook for other modules like QueryBuilder and RubyLess)
        {}
      end

      # Get a variable name and store the name in context variables for the given group.
      #
      # ==== Parameters
      #
      # * +group_name+  - name of the variable context group
      # * +wanted_name+ - wanted variable name (used as key to get real var back later with #get_context_var)
      # * +context+ - (optional) can be used if we do not want to store the variable definition in the current context
      #
      def get_var_name(group_name, wanted_name, context = @context)
        secure_name = wanted_name.gsub(/[^a-zA-Z0-9]/,'')
        name = "_z#{secure_name}"
        i    = 0
        while get_context_var('var', name, context)
          i += 1
          name = "_z#{secure_name}#{i}"
        end
        set_context_var('var', name, true)
        set_context_var(group_name, wanted_name, name)
        name
      end

      # Change context for a given scope.
      def with_context(cont, merge = true)
        raise "Block missing" unless block_given?
        cont_bak = @context
          if merge
            @context = @context.merge(cont)
          else
            @context = cont
          end
          res = yield
        @context = cont_bak
        res
      end

      # This should be called when we enter a new node context so that the proper hooks are
      # triggered (insertion of contextual variables).
      def open_node_context(finder, cont = {})
        sub_context = node_context_vars(finder).merge(cont)

        with_context(sub_context) do
          yield
        end
      end
    end # Context
  end # Process
end # Zafu
