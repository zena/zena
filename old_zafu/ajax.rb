module Zafu
  module Ajax
    # TODO: write a test (please)
    # FIXME: we should use a single way to change a whole context into a template (applies to 'each', 'form', 'block'). Then 'swap' could use the 'each' block.
    # Define a block of elements to be used by ajax calls (edit/filter)
    def r_block
      if @context[:block] == self
        # called from self (storing template)
        @context.reject! do |k,v|
          # FIXME: reject all stored elements in a  better way then this
          k.kind_of?(String) && k =~ /\ANode_\w/
        end
        @html_tag_done = false
        @html_tag_params.merge!(:id=>erb_dom_id)
        @context[:scope_node] = node if @context[:scope_node]
        out expand_with(:node => node)
        if @method == 'drop' && !@context[:make_form]
          out drop_javascript
        end
      else
        if parent.method == 'each' && @method == parent.single_child_method
          # use parent as block
          # FIXME: will not work with block as distant target...
          # do nothing
        else
          @html_tag ||= 'div'
          new_dom_scope

          unless @context[:make_form]
            # STORE TEMPLATE ========

            context_bak = @context.dup # avoid side effects when rendering the same block
            ignore_list = @method == 'block' ? ['form'] : [] # do not show the form in the normal template of a block
            template    = expand_block(self, :block=>self, :list=>false, :saved_template=>true, :ignore => ignore_list)
            @context    = context_bak
            @result     = ''
            out helper.save_erb_to_url(template, template_url)

            # STORE FORM ============
            if edit = descendant('edit')
              publish_after_save = (edit.params[:publish] == 'true')
              if form = descendant('form')
                # USE BLOCK FORM ========
                form_text = expand_block(form, :saved_template=>true, :publish_after_save => publish_after_save)
              else
                # MAKE A FORM FROM BLOCK ========
                form = self.dup
                form.method = 'form'
                form_text = expand_block(form, :make_form => true, :list => false, :saved_template => true, :publish_after_save => publish_after_save)
              end
              out helper.save_erb_to_url(form_text, form_url)
            end
          end

          # RENDER
          @html_tag_done = false
          @html_tag_params.merge!(:id=>erb_dom_id)
        end

        out expand_with
        if @method == 'drop' && !@context[:make_form]
          out drop_javascript
        end
      end
    end

    protected
  end # Ajax
end # Zafu