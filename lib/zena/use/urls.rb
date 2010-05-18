module Zena
  module Use
    module Urls
      module Common
        CACHESTAMP_FORMATS = ['jpg', 'png', 'gif', 'css', 'js']
        def prefix
          if visitor.is_anon?
            visitor.lang
          else
            AUTHENTICATED_PREFIX
          end
        end

        # Path for a node. Options can be :format, :host and :mode.
        # ex '/en/document34_print.html'
        def zen_path(node, options={})

          return '#' unless node

          if anchor = options.delete(:anchor)
            return "#{zen_path(node, options)}##{anchor}"
          end

          opts   = options.dup
          format = opts.delete(:format)
          if format.blank?
            format = 'html'
          elsif format == 'data'
            if node.kind_of?(Document)
              format = node.ext
            else
              format = 'html'
            end
          end

          pre    = opts.delete(:prefix) || (visitor.is_anon? && opts.delete(:lang)) || prefix
          mode   = opts.delete(:mode)
          host   = opts.delete(:host)
          abs_url_prefix = host ? "http://#{host}" : ''

          if node.kind_of?(Document) && format == node.ext
            if node.public? && !visitor.site.authentication?
              # force the use of a cacheable path for the data, even when navigating in '/oo'
              pre = node.version.lang
            end
          end

          if asset = opts.delete(:asset)
            mode   = nil
          end


          if cachestamp_format?(format) && ((node.kind_of?(Document) && node.prop['ext'] == format) || asset)
            opts[:cachestamp] = make_cachestamp(node, mode)
          else
            opts.delete(:cachestamp) # cachestamp
          end

          path = if !asset && node[:id] == visitor.site[:root_id] && mode.nil? && format == 'html'
            "#{abs_url_prefix}/#{pre}" # index page
          elsif node[:custom_base]
            "#{abs_url_prefix}/#{pre}/" +
            node.basepath +
            (mode  ? "_#{mode}"  : '') +
            (asset ? ".#{asset}" : '') +
            (format == 'html' ? '' : ".#{format}")
          else
            "#{abs_url_prefix}/#{pre}/" +
            ((node.basepath != '' && !node.basepath.nil? )? "#{node.basepath}/"    : '') +
            (node.klass.downcase   ) +
            (node[:zip].to_s       ) +
            (mode  ? "_#{mode}"  : '') +
            (asset ? ".#{asset}" : '') +
            ".#{format}"
          end
          append_query_params(path, opts)
        end

        def append_query_params(path, opts)
          if opts == {}
            path
          else
            cachestamp = opts.delete(:cachestamp)
            list = opts.keys.map do |k|
              if value = opts[k]
                if value.respond_to?(:strftime)
                  # FIXME: I think this is not needed anymore (and removing time might not be a good idea).
                  "#{k}=#{value.strftime('%Y-%m-%d')}"
                else
                  "#{k}=#{CGI.escape(opts[k].to_s)}"
                end
              else
                nil
              end
            end.compact
            if cachestamp
              result = path + "?#{cachestamp}" + (list.empty? ? '' : "&#{list.sort.join('&')}")
              result
            else
              path + (list.empty? ? '' : "?#{list.sort.join('&')}")
            end
          end
        end

        # Url for a node. Options are 'mode' and 'format'
        # ex 'http://test.host/en/document34_print.html'
        def zen_url(node, opts={})
          zen_path(node,opts.merge(:host => visitor.site[:host]))
        end

        # Return the path to a document's data
        def data_path(node, opts={})
          if node.kind_of?(Document)
            zen_path(node, opts.merge(:format => node.prop['ext']))
          else
            zen_path(node, opts)
          end
        end

        def cachestamp_format?(format)
          CACHESTAMP_FORMATS.include?(format)
        end

        def make_cachestamp(node, mode)
          if mode
            if node.kind_of?(Image)
              if iformat = Iformat[mode]
                "#{node.updated_at.to_i + iformat[:hash_id]}"
              else
                # random (will raise a 404 error anyway)
                "#{node.updated_at.to_i + Time.now.to_i}"
              end
            else
              # same format but different mode ? foobar_iphone.css ?
              # will not be used.
              node.updated_at.to_i.to_s
            end
          else
            node.updated_at.to_i.to_s
          end
        end

        # Url parameters (without format/mode/prefix...)
        def query_params
          res = {}
          path_params.each do |k,v|
            next if [:mode, :format, :asset, :cachestamp].include?(k.to_sym)
            res[k.to_sym] = v
          end
          res
        end

        # Url parameters (without action,controller,path,prefix)
        def path_params
          res = {}
          params.each do |k,v|
            next if [:action, :controller, :path, :prefix, :id].include?(k.to_sym)
            res[k.to_sym] = v
          end
          res
        end


      end # Common

      module ControllerMethods
        include Common
      end # ControllerMethods

      module ViewMethods
        include Common
        include RubyLess
        safe_method [:url,  Node]     => {:class => String, :method => 'zen_url'}
        safe_method [:path, Node]     => {:class => String, :method => 'zen_path'}
        safe_method [:zen_path, Node, Hash]   => {:class => String, :accept_nil => true}
        safe_method [:zen_path, Node]         => {:class => String, :accept_nil => true}
        safe_method [:zen_path, String, Hash]   => {:class => String, :accept_nil => true, :method => 'dummy_zen_path'}
        safe_method [:zen_path, String]         => {:class => String, :accept_nil => true, :method => 'dummy_zen_path'}

        def dummy_zen_path(string, options = {})
          if anchor = options.delete(:anchor)
            "#{string}##{anchor}"
          else
            "#{string}"
          end
        end
      end # ViewMethods

      module ZafuMethods

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

        # Insert a named anchor
        def r_anchor
          @params[:anchor] ||= 'true'
          r_link
        end

        protected

          # Get default anchor name
          def get_anchor_name(anchor_name)
            if anchor_name == 'true'
              if node.will_be?(Node)
                'node#{id}'
              elsif node.will_be?(Version)
                'version#{node.id}_#{id}'
              else
                anchor_name
                # force compilation with Node context. Why ?
                #node_bak = @context[:node]
                #@context[:node] = node(Node)
                #  anchor_name = ::RubyLess.translate_string(anchor_name, self)
                #@context[:node] = node_bak
              end
            else
              anchor_name
            end
          end

        private
          def make_link(options = {})
            @markup.tag ||= 'a'

            if @markup.tag == 'a'
              markup = @markup
            else
              markup = Zafu::Markup.new('a')
            end

            steal_and_eval_html_params_for(markup, @params)

            markup.set_dyn_param(:href, "<%= #{make_href} %>")

            # This is to make sure live_id is set *inside* the <a> tag.
            if @live_param
              text = add_live_id(text_for_link, markup)
              @live_param = nil
            else
              text = text_for_link
            end

            markup.wrap text
=begin
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
              if lnode = get_context_var('set_var', value) && stored.klass <= Node
                # using stored node
              else
                lnode, klass = build_finder(:first, href, {})
                return unless lnode
                return parser_error("invalid class (#{klass})") unless klass.ancestors.include?(Node)
              end
            else
              # obj
              if node_class == Version
                lnode = "#{node}.node"
                opts[:lang] = "#{node}.lang"
              elsif node.will_be?(Node)
                lnode = node
              else
                lnode = @context[:previous_node]
              end
            end

            if fmt = params.delete(:format)
              if fmt == 'data'
                opts[:format] = "#{node}.ext"
              else
                opts[:format] = fmt.inspect
              end
            end

            if mode = params.delete(:mode)
              opts[:mode] = mode.inspect
            end

            if anchor = params.delete(:anchor)
              opts[:anchor] = anchor.inspect
            end

            if anchor_in = params.delete(:in)
              finder, klass = build_finder(:first, anchor_in, {})
              return unless finder
              return parser_error("invalid class (#{klass})") unless klass.ancestors.include?(Node)
              opts[:anchor_in] = finder
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
              next if k.to_s =~ /if_|set_|\A_/
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
=end
          end

          # Build the 'href' link
          def make_href
            anchor = @params[:anchor]
            if anchor && !@params[:href]
              # Link on same page
              return ::RubyLess.translate_string("##{get_anchor_name(anchor)}", self)
            end

            method      = 'zen_path'
            method_args = []
            hash_params = []

            if href = @params[:href]
              method_args << href
            elsif node.will_be?(Version)
              method_args << node(Node)
              hash_params << ":lang => this.lang"
            else
              method_args << 'this'
            end

            @params.each do |key, value|
              next if [:href, :eval, :text, :attr].include?(key)
              if key == :anchor
                value = get_anchor_name(value)
              end

              hash_params << ":#{key} => %Q{#{value}}"
            end

            unless hash_params.empty?
              method_args << hash_params.join(', ')
            end

            method = "#{method}(#{method_args.join(', ')})"

            ::RubyLess.translate(method, self)
          end

          # <r:link page='next'/> <r:link page='previous'/> <r:link page='list'/>
          def pagination_links
            # FIXME: replace @context[:paginate] with get_context_var('paginate', 'key')
            return parser_error("not in pagination scope") unless pagination_key = @context[:paginate]

            case @params[:page]
            when 'previous'
              out "<% if set_#{pagination_key}_previous = (set_#{pagination_key} > 1 ? set_#{pagination_key} - 1 : nil) -%>"
              # FIXME: remove the :vars thing and use set_context_var('paginate', 'previous', "set_#{pagination_key}")
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
                link_params = ''

                @params.each do |k,v|
                  next if [:tag, :page, :join, :page_count].include?(k)
                  link_params << "#{k}='#{v}'"
                end

                text = "#{open_tag}<r:link#{link_params} #{pagination_key}='[#{pagination_key}_page]' do='[#{pagination_key}_page]'/>#{close_tag}"
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

          def text_for_link(default = nil)
            if dynamic_blocks?
              expand_with
            else
              if method = get_attribute_or_eval(false)
                method.literal || "<%= #{method} %>"
              elsif default
                default
              elsif node.will_be?(Node)
                "<%= #{node}.prop['title'] %>"
              elsif node.will_be?(Version)
                "<%= #{node}.node.prop['title'] %>"
              elsif node.will_be?(Link)
                "<%= #{node}.name %>"
              else
                _('edit')
              end
            end
          end
      end # ZafuMethods
    end # Urls
  end # Use
end # Zena