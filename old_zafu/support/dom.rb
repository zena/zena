module Zafu
  module Support
    module Dom

      def start_node_s_param(type = :input)
        if type == :input
          "<input type='hidden' name='s' value='<%= params[:s] || @node[:zip] %>'/>"
        elsif type == :erb
          "s=<%= params[:s] || @node[:zip] %>"
        elsif type == :value
          "<%= params[:s] || @node[:zip] %>"
        else
          "s=\#{params[:s] || @node[:zip]}"
        end
      end

      def erb_node_id(obj = node)
        if node.will_be?(Version)
          "<%= #{obj}.node.zip %>.<%= #{obj}.number %>"
        else
          "<%= #{node_id(obj)} %>"
        end
      end

      def node_id(obj = node)
        "#{obj}.zip"
      end

      # DOM id for the current context
      def dom_id(suffix='')
        return "\#{dom_id(#{node})}" if @context && (@context[:saved_template] && @context[:main_node])
        if @context && scope_node = @context[:scope_node]
          res = "#{dom_prefix}_\#{#{scope_node}.zip}"
        else
          res = dom_prefix
        end
        if (method == 'each' || method == 'each_group') && !@context[:make_form]
          "#{res}_\#{#{var}.zip}"
        elsif @context && @context[:in_calendar]
          "#{res}_\#{#{current_date}.to_i}"
        elsif method == 'unlink' || method == 'edit'
          target = nil
          parent = self.parent
          while parent
            if ['block', 'each', 'context', 'icon'].include?(parent.method)
              target = parent
              break
            end
            parent = parent.parent
          end
          target ? target.dom_id(suffix) : (res + suffix)
        else
          res + suffix
        end
      end

      def erb_dom_id(suffix='')
        return "<%= dom_id(#{node}) %>" if @context && (@context[:saved_template] && @context[:main_node])
        if @context && scope_node = @context[:scope_node]
          res = "#{dom_prefix}_<%= #{scope_node}.zip %>"
        else
          res = dom_prefix
        end
        if (method == 'each' || method == 'each_group') && !@context[:make_form]
          "#{res}_<%= #{var}.zip %>"
        elsif method == 'draggable'
          "#{res}_<%= #{node}.zip %>"
        elsif @context && @context[:in_calendar]
          "#{res}_<%= #{current_date}.to_i %>"
        elsif method == 'unlink'
          target = nil
          parent = self.parent
          while parent
            if ['block', 'each', 'context', 'icon'].include?(parent.method)
              target = parent
              break
            end
            parent = parent.parent
          end
          target ? target.erb_dom_id(suffix) : (res + suffix)
        else
          res + suffix
        end
      end

      # use our own scope
      def clear_dom_scope
        @context.delete(:make_form)      # should not propagate
        @context.delete(:main_node)      # should not propagate
      end

      # create our own ajax DOM scope
      def new_dom_scope
        clear_dom_scope
        @context.delete(:saved_template) # should not propagate on fresh template
        @context.delete(:dom_prefix)     # should not propagate on fresh template
        @context[:main_node]  = true     # the current context will be rendered with a fresh '@node'
        @context[:dom_prefix] = self.dom_prefix
      end

    end # Dom
  end # Support
end # Zafu