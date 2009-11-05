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
        if node_kind_of?(Version)
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

      # Unique template_url, ending with dom_id
      def template_url
        "#{@options[:root]}/#{dom_prefix}"
      end

      def form_url
        template_url + '_form'
      end

      # prefix for DOM id
      def dom_prefix
        (@context ? @context[:dom_prefix] : nil) || (@dom_prefix ||= unique_name)
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

      # Return a different name on each call
      def unique_name(base = context_name)
        root.next_name_index(base, base == @name).gsub(/[^\d\w\/]/,'_')
      end

      def context_name
        @name || if @context
          @context[:name] || 'list'
        elsif parent
          parent.context_name
        else
          'root'
        end
      end

      def next_name_index(key, own_id = false)
        @next_name_index ||= {}
        if @next_name_index[key]
          @next_name_index[key] += 1
          key + @next_name_index[key].to_s
        elsif own_id
          @next_name_index[key] = 0
          key
        else
          @next_name_index[key] = 1
          key + '1'
        end
      end
    end # Dom
  end # Support
end # Zafu