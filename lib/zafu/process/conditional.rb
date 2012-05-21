module Zafu
  module Process
    # This module manages conditional rendering (if, else, elsif, case, when).
    module Conditional
      def r_if(cond = nil)
        cond ||= get_condition
        return unless cond
        expand_if(cond)
      end

      def r_case
        r_if('false')
      end

      def r_else
        r_elsif('true')
      end

      def r_when
        r_elsif
      end

      def r_elsif(cond = nil)
        return '' unless @context[:in_if]
        cond ||= get_condition
        return unless cond

        res = expand_with(:in_if => false, :markup => nil)

        # We use 'elsif' just in case there are more then one 'else' clause
        if markup = @context[:markup]
          if @markup.tag.blank?
            # Copy markup tag
            @markup.tag = markup.tag
            @markup.steal_html_params_from(@params)
            markup.params.each do |k, v|
              next if @markup.params[k]
              @markup.set_param(k, v)
            end

            markup.dyn_params.each do |k, v|
              next if @markup.params[k] || @markup.dyn_params[k]
              @markup.set_dyn_param(k, v)
            end
            inner = wrap(res)
          else
            markup.done = false
            # Wrap with both markup (ours and the else/elsif clause).
            inner = markup.wrap(wrap(res))
          end
          out "<% elsif #{cond} %>#{inner}" # do not propagate
        else
          #@markup.done = true # never wrap else/elsif clause
          out "<% elsif #{cond} %>#{res}" # do not propagate
        end
      end

      # Expand blocks with conditional processing enabled (else, elsif, etc).
      #
      # ==== Parameters
      #
      # * +condition+ - ruby condition for the conditional execution.
      # * +new_node_context+ - (optional) new node context to enter if the clause succeeds.
      # * +alt_markup+ - (optional) alternative markup to use for the 'else', 'elsif' clauses.
      def expand_if(condition, new_node_context = self.node, alt_markup = @markup)
        res = ""
        res << "<% if #{condition} %>"
        with_context(:node => new_node_context) do
          res << wrap(expand_with)
        end

        only = method == 'case' ? %r{^[A-Z]|else|elsif|when} : %w{else elsif when}
        res << expand_with(:in_if => true, :only => only, :markup => alt_markup)
        res << "<% end %>"
        res
      end

      private
        def get_condition
          if in_tag = @params[:in]
            if in_tag == 'form' && @context[:make_form]
              'true'
            else
              ancestor(in_tag) ? 'true' : 'false'
            end
          else
            get_attribute_or_eval(false)
          end
        end
    end # Context
  end # Process
end # Zafu
