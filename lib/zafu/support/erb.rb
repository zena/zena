module Zafu
  module Support
    module Erb

      def params_to_erb(params, initial_comma = true)
        res = initial_comma ? [""] : []
        params.each do |k,v|
          if v =~ /<%=/ && !(v =~ /"/)
            # replace by #{}
            val = v.gsub('#{', '# {').gsub(/<%=(.*?)%>/,'#{\1}')
            res << "#{k.inspect}=>\"#{val}\""
          else
            res << "#{k.inspect}=>#{v.inspect}"
          end
        end
        res.join(', ')
      end

      def get_text_for_erb(params = @params, use_blocks = true, context = :erb)
        string_context = context == :string
        if params[:attr]
          string_context ? "<%= #{node_attribute(params[:attr])} %>" : node_attribute(params[:attr])
        elsif params[:tattr]
          string_context ? "<%= _(#{node_attribute(params[:tattr])}) %>" : "_(#{node_attribute(params[:tattr])})"
        elsif params[:trans]
          string_context ? _(params[:trans]) : _(params[:trans]).inspect
        elsif params[:text]
          string_context ? params[:text] : params[:text].inspect
        elsif use_blocks && @blocks != []
          res  = []
          text = ""
          static = true
          @blocks.each do |b|
            # FIXME: this is a little too hacky
            if b.kind_of?(String)
              res  << b.inspect
              text << b
            elsif ['show', 'img'].include?(b.method)
              res << expand_block(b, :trans=>true)
              static = false
            elsif ['rename_asset', 'trans'].include?(b.method)
              # FIXME: if a trans contains non-static: static should become false
              res  << expand_block(b).inspect
              text << expand_block(b)
            else
              # ignore
            end
          end
          if static
            # "just plain text"
            string_context ? text : text.inspect
          else
            # function(...) + "blah" + function()
            string_context ? "<%= #{res.join(' + ')} %>" : res.join(' + ')
          end
        else
          nil
        end
      end
    end # Erb
  end # Support
end # Zafu
