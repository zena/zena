module Zafu
  module Process
    module Forms
      def self.included(base)
        base.expander :make_form
      end

      def r_form
        if node.dom_prefix
          fnode = node
        else
          fnode = node.dup
          fnode.dom_prefix = dom_name
        end
        with_context(:node => fnode) do
          
          unless @params[:on].nil? || @params[:on].split(',').include?(@context[:ajax_action])
            return ''
          end

          return parser_error('Cannot render update form in list context.') if node.list_context?

          options = form_options

          @markup.set_id(options[:id]) if options[:id]
          @markup.set_param(:style, options[:style]) if options[:style]

          if descendant('form_tag')
            # We have a specific place to insert our form
            out expand_with(:form_options => options, :form => self)
          else
            r_form_tag(options)
          end
        end
      end

      def r_form_tag(options = @context[:form_options])
        form_tag(options) do |opts|
          # Render error messages tag
          form_error_messages(opts[:form_helper])

          # Render form elements
          out expand_with(opts)

          # Render hidden fields (these must go after normal elements so that focusFirstElement works)
          hidden_fields = form_hidden_fields(options)

          out "<div class='hidden'>"
          hidden_fields.each do |k,v|
            if v.kind_of?(String)
              v = "'#{v}'" unless v.kind_of?(String) && ['"', "'"].include?(v[0..0])
              out "<input type='hidden' name='#{k}' value=#{v}/>"
            elsif v.kind_of?(Array)
              # We use ['ffff'] to indicate that the content is already escaped and ready for ERB.
              out v.first
            end
          end
          out '</div>'
        end
      end

      private
        def make_form
          return nil unless @context[:make_form]

          if method == 'each' || method == 'block'
            r_form
          else
            nil
          end
        end

        # Return id, style, form and cancel parts of the form.
        def form_options
          opts = {}
          
          # Do we need this ?
          # opts[:klass] = node.master_class(ActiveRecord::Base).to_s

          if @context[:in_add]
            opts[:id]    = "#{node.dom_prefix}_add"
            opts[:style] = 'display:none;'
          elsif @markup.tag == 'table'
            # the normal id goes to the form wrapping the table
            opts[:id]    = "#{node.dom_prefix}_tbl"
            form_id      = node.dom_prefix
          end
          
          form_id ||= "#{node.dom_prefix}_form_t"
          if @context[:template_url]
            opts[:form_tag]    = "<% remote_form_for(:#{node.form_name}, #{node}, :html => {:id => #{form_id.inspect}}) do |f| %>"
            opts[:form_helper] = 'f'
          else
            opts[:form_tag]    = "<% form_for(:#{node.form_name}, #{node}, :html => {:id => #{form_id.inspect}}) do |f| %>"
            opts[:form_helper] = 'f'
          end
          opts[:form_prefix] = node.dom_prefix || dom_name
          opts
        end

        # Return hidden fields that need to be inserted in the form.
        def form_hidden_fields(opts)
          if t_url = @context[:template_url]
            {'t_url' => t_url}
          else
            {}
          end
        end

        # Render the 'form' tag and set expansion context.
        def form_tag(options)
          opts = options.dup

          if descendant('cancel') || descendant('edit')
            # Pass 'form_cancel' content to expand_with (already in options).
          else
            # Insert cancel before form
            out opts.delete(:form_cancel).to_s
          end

          # form_for ... do |f|
          out opts.delete(:form_tag)
            # f.xxx
            if markup.tag == 'table'
              # Avoid <table><form> (invalid HTML)
              bak = @result
              @result = ''
              yield(opts.merge(:in_form => true))
              @result = bak + markup.wrap(@result)
            else
              yield(opts.merge(:in_form => true))
            end
          # close form
          out opts[:form_helper] ? "<% end %>" : '</form>'
        end

        def form_error_messages(f)
          out "<%= #{f}.error_messages %>"
        end

    end # Forms
  end # Process
end # Zafu
