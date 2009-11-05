module Zafu
  module Support
    module Links

      # creates a link. Options are:
      # :href (node, parent, project, root)
      # :tattr (translated attribute used as text link)
      # :attr (attribute used as text link)
      # <r:link href='node'><r:trans attr='lang'/></r:link>
      # <r:link href='node' tattr='lang'/>
      # <r:link update='dom_id'/>
      # <r:link page='next'/> <r:link page='previous'/> <r:link page='list'/>
      def r_link
        if @params[:page] && @params[:page] != '[page_page]' # lets users use 'page' as pagination key
          pagination_links
        else
          make_link
        end
      end

      def make_link(options = {})
        query_params = options[:query_params] || {}
        default_text = options[:default_text]
        params = {}
        (options[:params] || @params).each do |k,v|
          next if v.nil?
          params[k] = v
        end

        opts = {}
        if upd = params.delete(:update)
          return unless remote_target = find_target(upd)
        end

        if href = params.delete(:href)
          if lnode = find_stored(Node, href)
            # using stored node
          else
            lnode, klass = build_finder_for(:first, href, {})
            return unless lnode
            return parser_error("invalid class (#{klass})") unless klass.ancestors.include?(Node)
          end
        else
          # obj
          if node_class == Version
            lnode = "#{node}.node"
            opts[:lang] = "#{node}.lang"
          elsif node_kind_of?(Node)
            lnode = node
          else
            lnode = @context[:previous_node]
          end
        end

        if fmt = params.delete(:format)
          if fmt == 'data'
            opts[:format] = "#{node}.c_ext"
          else
            opts[:format] = fmt.inspect
          end
        end

        if mode = params.delete(:mode)
          opts[:mode] = mode.inspect
        end

        if sharp = params.delete(:sharp)
          opts[:sharp] = sharp.inspect
        end

        if sharp_in = params.delete(:in)
          finder, klass = build_finder_for(:first, sharp_in, {})
          return unless finder
          return parser_error("invalid class (#{klass})") unless klass.ancestors.include?(Node)
          opts[:sharp_in] = finder
        end

        if @html_tag && @html_tag != 'a'
          # FIXME: can we remove this ?
          # html attributes do not belong to anchor
          pre_space = ''
          html_params = {}
        else
          html_params = get_html_params(params.merge(@html_tag_params), :link)
          pre_space = @space_before || ''
          @html_tag_done = true
        end

        (params.keys - [:style, :class, :id, :rel, :name, :anchor, :attr, :tattr, :trans, :text]).each do |k|
          next if k.to_s =~ /if_|set_/
          query_params[k] = params[k]
        end

        # TODO: merge these two query_params cleanup things into something cleaner.
        if remote_target
          # ajax
          query_params_list = []
          query_params.each do |k,v|
            if k == :date
              if v == 'current_date'
                str = "\#{#{current_date}}"
              elsif v =~ /\A\d/
                str = CGI.escape(v.gsub('"',''))
              elsif v =~ /\[/
                attribute, static = parse_attributes_in_value(v.gsub('"',''), :erb => false)
                str = static ? CGI.escape(attribute) : "\#{CGI.escape(\"#{attribute}\")}"
              else
                str = "\#{CGI.escape(#{node_attribute(v)})}"
              end
            else
              attribute, static = parse_attributes_in_value(v.gsub('"',''), :erb => false)
              str = static ? CGI.escape(attribute) : "\#{CGI.escape(\"#{attribute}\")}"
            end
            query_params_list << "#{k.to_s.gsub('"','')}=#{str}"
          end
          pre_space + link_to_update(remote_target, :node_id => "#{lnode}.zip", :query_params => query_params_list, :default_text => default_text, :html_params => html_params)
        else
          # direct link
          query_params.each do |k,v|
            if k == :date
              if v == 'current_date'
                query_params[k] = current_date
              elsif v =~ /\A\d/
                query_params[k] = v.inspect
              elsif v =~ /\[/
                attribute, static = parse_attributes_in_value(v.gsub('"',''), :erb => false)
                query_params[k] = "\"#{attribute}\""
              else
                query_params[k] = node_attribute(v)
              end
            else
              attribute, static = parse_attributes_in_value(v.gsub('"',''), :erb => false)
              query_params[k] = "\"#{attribute}\""
            end
          end

          query_params.merge!(opts)

          opts_str = ''
          query_params.keys.sort {|a,b| a.to_s <=> b.to_s }.each do |k|
            opts_str << ",:#{k.to_s.gsub(/[^a-z_A-Z_]/,'')}=>#{query_params[k]}"
          end

          opts_str += ", :host => #{@context["exp_host"]}" if @context["exp_host"]

          pre_space + "<a#{params_to_html(html_params)} href='<%= zen_path(#{lnode}#{opts_str}) %>'>#{text_for_link(default_text)}</a>"
        end
      end

      # <r:link page='next'/> <r:link page='previous'/> <r:link page='list'/>
      def pagination_links
        return parser_error("not in pagination scope") unless pagination_key = @context[:paginate]

        case @params[:page]
        when 'previous'
          out "<% if set_#{pagination_key}_previous = (set_#{pagination_key} > 1 ? set_#{pagination_key} - 1 : nil) -%>"
          @context[:vars] ||= []
          @context[:vars] << "#{pagination_key}_previous"
          out make_link(:default_text => "<%= set_#{pagination_key}_previous %>", :query_params => {pagination_key => "[#{pagination_key}_previous]"}, :params => @params.merge(:page => nil))
          if descendant('else')
            out expand_with(:in_if => true, :only => ['else', 'elsif'])
          end
          out "<% end -%>"
        when 'next'
          out "<% if set_#{pagination_key}_next = (set_#{pagination_key}_count - set_#{pagination_key} > 0 ? set_#{pagination_key} + 1 : nil) -%>"
          @context[:vars] ||= []
          @context[:vars] << "#{pagination_key}_next"
          out make_link(:default_text => "<%= set_#{pagination_key}_next %>", :query_params => {pagination_key => "[#{pagination_key}_next]"}, :params => @params.merge(:page => nil))
          if descendant('else')
            out expand_with(:in_if => true, :only => ['else', 'elsif'])
          end
          out "<% end -%>"
        when 'list'
          @context[:vars] ||= []
          @context[:vars] << "#{pagination_key}_page"
          if @blocks == [] || (@blocks.size == 1 && !@blocks.first.kind_of?(String) && @blocks.first.method == 'else')
            # add a default block
            if tag = @params[:tag]
              open_tag = "<#{tag}>"
              close_tag = "</#{tag}>"
            else
              open_tag = close_tag = ''
            end
            link_params = {}
            @params.each do |k,v|
              next if [:tag, :page, :join, :page_count].include?(k)
              link_params[k] = v
            end
            text = "#{open_tag}<r:link #{params_to_html(link_params)} #{pagination_key}='[#{pagination_key}_page]' do='[#{pagination_key}_page]'/>#{close_tag}"
            @blocks = [make(:void, :method=>'void', :text=>text)]
            remove_instance_variable(:@all_descendants)
          end

          if !descendant('else')
            @blocks += [make(:void, :method=>'void', :text=>"<r:else>#{open_tag}<r:show var='#{pagination_key}_page'/>#{close_tag}</r:else>")]
            remove_instance_variable(:@all_descendants)
          end

          out "<% page_numbers(set_#{pagination_key}, set_#{pagination_key}_count, #{(@params[:join] || ' ').inspect}, #{@params[:page_count] ? @params[:page_count].to_i : 'nil'}) do |set_#{pagination_key}_page, #{pagination_key}_page_join| %>"
          out "<%= #{pagination_key}_page_join %>"
          out "<% if set_#{pagination_key}_page != set_#{pagination_key} -%>"
          out expand_with(:in_if => true)
          out "<% end; end -%>"
        else
          parser_error("unkown option for 'page' #{@params[:page].inspect} should be ('previous', 'next' or 'list')")
        end
      end

      def r_anchor(obj=node)
        "<a name='#{anchor_name(@anchor_param, obj)}'></a>"
      end

      def r_check_lang
        text = @params[:text]   || expand_with
        klass = @params[:class] || @html_tag_params[:class]
        text = nil if text.blank?
        klas = nil if klass.blank?
        @html_tag_done = true
        "#{@space_before}<%= check_lang(#{node},:text=>#{text.inspect},:class=>#{klass.inspect},:wrap=>#{@html_tag.inspect}) %>"
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

        query_params << "link_id=\#{#{node}.link_id}" if @context[:need_link_id] && node_kind_of?(Node)
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

      def text_for_link(default = nil)
        if @blocks.size > 1 || (@blocks.size == 1 && !(@blocks.first.kind_of?(String) || ['else','elsif'].include?(@blocks.first.method)))
          expand_with
        elsif default
          default
        elsif erb_text = get_text_for_erb(@params, false, :string)
          erb_text
        elsif node_kind_of?(Node)
          "<%= #{node}.version.title %>"
        elsif node_kind_of?(Version)
          "<%= #{node}.title %>"
        elsif node_kind_of?(Link)
          "<%= #{node}.name %>"
        else
          _('edit')
        end
      end
    end # Links
  end # Support
end # Zafu