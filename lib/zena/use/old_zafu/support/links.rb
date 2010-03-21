module Zafu
  module Support
    module Links

      def r_anchor(obj=node)
        if single_child_method == 'link'
          link = @blocks[0]
          link.params.merge!(:_name => anchor_name(params[:type] || 'true', obj))
          expand_block(link)
        else
          "<a name='#{anchor_name(@anchor_param, obj)}'></a>"
        end
      end

      def anchor_name(p, obj=node)
        if p =~ /\[(.+)\]/
          "<%= #{node_attribute($1)} %>"
        else
          "#{base_class.to_s.underscore}#{erb_node_id(obj)}"
        end
      end

      def link_to_update(target, opts = {})
        method = opts[:method] || :get

        html_params = opts[:html_params] || {}
        node_id = opts[:node_id] || self.node_id

        url    = opts[:url]    || "/#{base_class.to_s.pluralize.underscore}/\#{#{node_id}}#{method == :get ? '/zafu' : ''}"
        opts[:cond]   ||= "#{node}.can_write?" if method != :get

        query_params = [opts[:query_params]].flatten.compact

        if method == :get
          if target
            query_params << "t_url=#{CGI.escape(target.template_url)}"
            query_params << "dom_id=#{target.dom_id}"
          else
            query_params << "dom_id=_page"
          end
        else
          query_params << "t_url=#{CGI.escape(template_url)}" if method != :delete

          query_params << "dom_id=#{dom_id}"
          if target != self
            if target
              query_params << "u_url=#{CGI.escape(target.template_url)}"
              query_params << "udom_id=#{target.dom_id}"
            else
              query_params << "udom_id=_page"
            end
          end
        end

        query_params << "link_id=\#{#{node}.link_id}" if @context[:need_link_id] && node.will_be?(Node)
        query_params << "node[v_status]=#{Zena::Status[:pub]}" if @params[:publish] # FIXME: this acts like publish = 'force'
        query_params << start_node_s_param(:string)

        res = ''
        res += "<% if #{opts[:cond]} -%>" if opts[:cond]
        res += "<%= tag_to_remote({:url => \"#{url}?#{query_params.join('&')}\", :method => #{method.inspect}}#{params_to_erb(html_params)}) %>"
        res += text_for_link(opts[:default_text])
        res += "</a>"
        if opts[:cond]
          if opts[:else] != :void
            res += "<% else -%>"
            res += text_for_link(opts[:default_text])
          end
          res += "<% end -%>"
        end
        res
      end
    end # Links
  end # Support
end # Zafu