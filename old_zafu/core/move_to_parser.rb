# Elements here should be moved to the core zafu parser
module Zafu
  module Core
    module MoveToParser
      def before_render
        return unless super

        @var = nil # reset var counter

        if key = @params[:store]
          set_stored(Node, key, node)
        end

        if key = @params[:store_date]
          set_stored(Date, key, current_date)
        end
        if @method != 'link'
          @anchor_param = @params[:anchor]
        end

        true
      end


      def after_render(text)
        if @anchor_param
          @params[:anchor] = @anchor_param # set back in case of double rendering so it is computed again
          r_anchor + super
        else
          super
        end
      end

      # Our special version of r_expand_with tag with "set_" parsing.
      def r_expand_with
        hash = {}
        @params.each do |k,v|
          if k.to_s =~ /^set_(.+)$/
            # TODO: DRY with render_html_tag
            k   = $1
            value, static = parse_attributes_in_value(v, :erb => false)
            hash["exp_#{k}"] = static ? value.inspect : "\"#{value}\""
          else
            hash["exp_#{k}"] = v.inspect
          end
        end
        @params = {}
        expand_with(hash)
      end

      def expand_with(acontext={})
        # set variables
        context = nil
        pre = ''
        @blocks.each do |block|
          next if block.kind_of?(String) || block.method != 'set'
          @context[:vars] ||= []
          context ||= @context.merge(acontext).merge(:set => true)
          pre << expand_block(block, context)
          @context[:vars] << block.params[:var]
        end

        pre + super
      end

      def context
        return @context if @context
        # not rendered yet, find first parent with context
        @context = parent ? parent.context : {}
      end

    end # MoveToParser
  end # Core
end # Zafu