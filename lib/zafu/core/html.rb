module Zafu
  module Core
    module HTML
      def get_html_params(params, tag_type)
        res  = {}
        params.each do |k,v|
          next unless v
          if k.to_s =~ /\A(t?)set_(.+)$/
            key   = $2
            trans = $1 == 't'
            value, static = parse_attributes_in_value(v, :erb => !trans)

            if trans
              if static
                value = ["'#{_(value)}'"]            # array so it is not escaped on render
              else
                value = ["'<%= _(\"#{value}\") %>'"] # FIXME: use dict ! array so it is not escaped on render
              end
            end
            res[key.to_sym] = value
          elsif tag_type == :link && k == :_name
            # :_name set by r_anchor
            res[:name] ||= v
          elsif tag_type == :link && ![:style, :class, :id, :title].include?(k)
            # bad html parameter for links (some keys for link tags are used as query parameters)
            # filter out
          else
            res[k] ||= v
          end
        end

        #if params[:anchor]
        #  @anchor_param = nil
        #  res[:name] = anchor_name(params[:anchor], node)
        #end

        res
      end

      # Add a class name to the html_tag
      def add_html_class(class_name)
        if klass = @html_tag_params[:class]
          @html_tag_params[:class] = "#{class_name} #{klass}"
        else
          @html_tag_params[:class] = class_name
        end
      end

      def render_html_tag(text,*append)
        append ||= []
        return text if @html_tag_done
        set_params  = {}
        if_params   = {}
        @params.each do |k,v|
          if k.to_s =~ /^t?set_/
            set_params[k] = v
          end
        end
        tag_class = @html_tag_params[:class] || @params[:class]
        if node_kind_of?(Node)

          if @context[:make_form]
            node_name = node
          elsif (@method == 'each' || @method == 'each_group') && @context[:list]
            node_name = var
          elsif @method == 'context' || !respond_to?("r_#{@method}".to_sym)
            node_name = @var || node
          else
            node_name = node
          end

          class_cond = nil
          @params.each do |k,v|
            if k.to_s =~ /^(.+)_if$/
              klass = $1
              cond  = get_test_condition(node_name, :test => v)
            elsif k.to_s =~ /^(.+)_if_(test|node|kind_of|klass|status|lang|can|in)$/
              klass = $1
              cond  = get_test_condition(node_name, $2.to_sym => v)
            end
            if cond
              class_cond = "#{cond} ? \" class='#{klass}'\" : #{class_cond}" # (x = 3) ? "class='foo'" :
            end
          end

          if class_cond
            append << "<%= #{class_cond}\"#{tag_class ? " class='#{tag_class}'" : ""}\" %>"
            @html_tag_params.delete(:class)
          end
        end

        @html_tag = 'div' if !@html_tag && (set_params != {} || @html_tag_params != {})

        bak = @html_tag_params.dup
        @html_tag_params = get_html_params(set_params.merge(@html_tag_params), @html_tag)
        res = super(text,*append)
        @html_tag_params = bak
        res
      end
    end # HTML
  end # Core
end # Zafu