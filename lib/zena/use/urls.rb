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

        # We overwrite some url writers that might use Node so that they use
        # zip instead of id.
        %w{edit delete drop zafu}.each do |method|
          class_eval %Q{
            def #{method}_node_path(node, options={}) # def edit_node_path(node, options={})
              if node.kind_of?(Node)                  #   if node.kind_of?(Node)
                super(node.zip, options)              #     super(node.zip, options)
              else                                    #   else
                super                                 #     super
              end                                     #   end
            end                                       # end
          }
        end

        # Path to remove a node link.
        def unlink_node_path(node, options={})
          return '#' unless node.can_write? && node.link_id
          node_link_path(node.zip, node.link_id, options)
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
            ((node.basepath != '' && !node.basepath.nil? )? "#{node.basepath}/" : '') +
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

        safe_method [:zen_path, Node, Hash]     => {:class => String, :accept_nil => true}
        safe_method [:zen_path, Node]           => {:class => String, :accept_nil => true}
        safe_method [:zen_path, String, Hash]   => {:class => String, :accept_nil => true, :method => 'dummy_zen_path'}
        safe_method [:zen_path, String]         => {:class => String, :accept_nil => true, :method => 'dummy_zen_path'}

        safe_method [:zafu_node_path, Node, Hash]   => {:class => String, :accept_nil => true}
        safe_method [:zafu_node_path, Node]         => {:class => String, :accept_nil => true}
        safe_method [:edit_node_path, Node, Hash]   => {:class => String, :accept_nil => true}
        safe_method [:edit_node_path, Node]         => {:class => String, :accept_nil => true}
        safe_method [:delete_node_path, Node, Hash] => {:class => String, :accept_nil => true}
        safe_method [:delete_node_path, Node]       => {:class => String, :accept_nil => true}
        safe_method [:drop_node_path, Node, Hash]   => {:class => String, :accept_nil => true}
        safe_method [:drop_node_path, Node]         => {:class => String, :accept_nil => true}
        safe_method [:unlink_node_path, Node, Hash]   => {:class => String, :accept_nil => true}
        safe_method [:unlink_node_path, Node]         => {:class => String, :accept_nil => true}

        safe_method :start_id  => {:class => Number, :method => 'start_node_zip'}

        def dummy_zen_path(string, options = {})
          if anchor = options.delete(:anchor)
            "#{string}##{anchor}"
          else
            "#{string}"
          end
        end
      end # ViewMethods

      module ZafuMethods
        include RubyLess

        # private
        safe_method :insert_dom_id => :insert_dom_id


        # Add the dom_id inside a RubyLess built method (used with make_href and ajax).
        #
        def insert_dom_id(signature)
          return nil if signature.size != 1
          {:method => @insert_dom_id, :class => String}
        end

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

        # Create a link tag.
        #
        # ==== Parameters (hash)
        #
        # * +:update+ - DOM_ID: produce an Ajax call that will update this part of the page (optional)
        # * +:default_text+ - default text to use for the link if there are no 'text', 'eval' or 'attr' params
        # * +:action+ - link action (edit, show, etc)
        #
        def make_link(options = {})
          remote_target = (options[:update] || @params.delete(:update))

          @markup.tag ||= 'a'

          if @markup.tag == 'a'
            markup = @markup
          else
            markup = Zafu::Markup.new('a')
          end

          steal_and_eval_html_params_for(markup, @params)

          href = make_href(remote_target, options)

          # This is to make sure live_id is set *inside* the <a> tag.
          if @live_param
            text = add_live_id(text_for_link, markup)
            @live_param = nil
          else
            text = text_for_link(options[:default_text])
          end

          if remote_target
            # ajax link (link_to_remote)

            # Add href to non-ajax method.
            markup.set_param(:href, "<%= #{make_href(nil, options.merge(:update => false))} %>")


            # Use onclick with Ajax.
            markup.set_dyn_param(:onclick, "new Ajax.Request(\"<%= #{href} %>\", {asynchronous:true, evalScripts:true, method:\"#{http_method_from_action(options[:action])}\"}); return false;")
          else
            markup.set_dyn_param(:href, "<%= #{href} %>")
          end

          markup.wrap(text)
=begin
          query_params = options[:query_params] || {}
          default_text = options[:default_text]
          params = {}
          (options[:params] || @params).each do |k,v|
            next if v.nil?
            params[k] = v
          end

          opts = {}

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
                #  anchor_name = ::RubyLess.translate_string(self, anchor_name)
                #@context[:node] = node_bak
              end
            else
              anchor_name
            end
          end

        private

          # Build the 'href' part of a link.
          #
          # ==== Parameters
          #
          # * +:remote_target+ - a processing node to update
          # * +:action+ - action to use ('edit', 'show'). Default is 'show'.
          #
          # ==== Examples
          #
          #   Product.count_by_sql "SELECT COUNT(*) FROM sales s, customers c WHERE s.customer_id = c.id"
          def make_href(remote_target = nil, opts = {})
            anchor = @params[:anchor]
            if anchor && !@params[:href]
              # Link on same page
              return ::RubyLess.translate_string(self, "##{get_anchor_name(anchor)}")
            end

            # if opts[:action] == 'edit' && !remote_target
            #   method = 'edit_node_path'
            # els
            if %w{edit drop unlink}.include?(opts[:action])
              method = "#{opts[:action]}_node_path"
            elsif remote_target
              method = 'zafu_node_path'
            else
              method = 'zen_path'
            end

            method_args = []
            hash_params = []

            # Select http verb.
            unless remote_target
              http_method = http_method_from_action(opts[:action])
              if http_method != 'get'
                hash_params << ":_method => '#{http_method}'"
              end
            end

            if href = @params[:href]
              method_args << href
            elsif node.will_be?(Version)
              method_args << "node"
              hash_params << ":lang => this.lang"
            elsif node.list_context?
              method_args << '@node'
            else
              method_args << 'this'
            end

            insert_ajax_args(remote_target, hash_params, opts[:action]) if remote_target

            (opts[:query_params] || @params).each do |key, value|
              next if [:href, :eval, :text, :attr].include?(key)
              if key == :anchor
                value = get_anchor_name(value)
              end

              hash_params << "#{key.inspect} => %Q{#{value}}"
            end

            unless hash_params.empty?
              method_args << hash_params.join(', ')
            end

            method = "#{method}(#{method_args.join(', ')})"

            ::RubyLess.translate(self, method)
          end

          def insert_ajax_args(target, hash_params, action)
            hash_params << ":s => start_id"
            hash_params << ":link_id => this.link_id" if @context[:has_link_id] && node.will_be?(Node)
            if target.kind_of?(String)
              # named target
              return nil unless target = find_target(target)
            end

            case action
            when 'edit'
              # 'each' target in parent hierarchy
              @insert_dom_id = %Q{"#{node.dom_id(:erb => false)}"}
              hash_params << ":dom_id => insert_dom_id"
              hash_params << ":t_url  => %Q{#{form_url(node.dom_prefix)}}"
              # To enable link edit fix the following line:
              # hash_params << "'node[link_id]' => link_id"
            when 'unlink', 'delete'
              @insert_dom_id = %Q{"#{node.dom_id(:erb => false)}"}
              hash_params << ":dom_id => insert_dom_id"
              hash_params << ":t_url  => %Q{#{template_url(target.name)}}"
            else # drop
              hash_params << ":dom_id => %Q{#{target.name}}" # target.node.dom_id
              hash_params << ":t_url  => %Q{#{template_url(target.name)}}"
            end

            # method = opts[:method] || :get
            #
            # html_params = opts[:html_params] || {}
            # node_id = opts[:node_id] || self.node_id
            #
            # url    = opts[:url]    || "/#{base_class.to_s.pluralize.underscore}/\#{#{node_id}}#{method == :get ? '/zafu' : ''}"
            # opts[:cond]   ||= "#{node}.can_write?" if method != :get
            #
            # query_params = [opts[:query_params]].flatten.compact
            #
            # if method == :get
            #   if target
            #     query_params << "t_url=#{CGI.escape(target.template_url)}"
            #     query_params << "dom_id=#{target.dom_id}"
            #   else
            #     query_params << "dom_id=_page"
            #   end
            # else
            #   query_params << "t_url=#{CGI.escape(template_url)}" if method != :delete
            #
            #   query_params << "dom_id=#{dom_id}"
            #   if target != self
            #     if target
            #       query_params << "u_url=#{CGI.escape(target.template_url)}"
            #       query_params << "udom_id=#{target.dom_id}"
            #     else
            #       query_params << "udom_id=_page"
            #     end
            #   end
            # end
            #
            # query_params << "node[v_status]=#{Zena::Status[:pub]}" if @params[:publish] # FIXME: this acts like publish = 'force'
            # query_params << start_node_s_param(:string)
            #
            # res = ''
            # res += "<% if #{opts[:cond]} -%>" if opts[:cond]
            # res += "<%= tag_to_remote({:url => \"#{url}?#{query_params.join('&')}\", :method => #{method.inspect}}#{params_to_erb(html_params)}) %>"
            # res += text_for_link(opts[:default_text])
            # res += "</a>"
            # if opts[:cond]
            #   if opts[:else] != :void
            #     res += "<% else -%>"
            #     res += text_for_link(opts[:default_text])
            #   end
            #   res += "<% end -%>"
            # end
            # res
          end

          # <r:link page='next'/> <r:link page='previous'/> <r:link page='list'/>
          def pagination_links

            return parser_error("not in pagination scope") unless pagination_key = get_context_var('paginate', 'key')
            page_direction = @params[:page]
            case page_direction
            when 'previous', 'next'
              current      = get_context_var('paginate', 'current')
              count        = get_context_var('paginate', 'count')
              prev_or_next = get_var_name('paginate', page_direction)

              if page_direction == 'previous'
                out "<% if #{prev_or_next} = (#{current} > 1 ? #{current} - 1 : nil) -%>"
              else
                out "<% if #{prev_or_next} = (#{count} - #{current} > 0 ? #{current} + 1 : nil) -%>"
              end

              # previous_page // next_page
              set_context_var('set_var', "#{page_direction}_page", RubyLess::TypedString.new(prev_or_next, :class => Number, :nil => true))

              #, :params => @params.merge(:page => nil))
              out make_link(:default_text => "<%= #{prev_or_next} %>", :query_params => {pagination_key => "\#{#{page_direction}_page}"})

              if descendant('else')
                out expand_with(:in_if => true, :only => ['else', 'elsif'])
              end
              out "<% end -%>"
            when 'list'

              node_count  = get_context_var('paginate', 'nodes')
              page_count  = get_context_var('paginate', 'count')
              curr_page   = get_context_var('paginate', 'current')
              page_number = get_var_name('paginate', 'page')
              page_join   = get_var_name('paginate', 'join')

              if @blocks == [] || (@blocks.size == 1 && !@blocks.first.kind_of?(String) && @blocks.first.method == 'else')
                # We need to insert the default 'link' tag: <r:link href='@node' #{pagination_key}='#{this}' ... do='this'/>
                link = {}
                @params.each do |k,v|
                  next if [:tag, :page, :join, :page_count].include?(k)
                  # transfer params
                  link[k] = v
                end
                tag = @params[:tag]

                link[:html_tag] = tag if tag
                link[:href] = '@node'
                link[:eval] = 'this'
                link[pagination_key.to_sym] = '#{this}'

                # <r:link href='@node' href='@node' p='#{this}' ... eval='this'/>

                @blocks = [make(:void, :method => 'link', :params => link)]
                # Clear cached descendants
                remove_instance_variable(:@all_descendants)
              end

              if !descendant('else')
                else_tag = {:method => 'else', :text => '<r:this/>'}
                else_tag[:tag] = tag if tag
                @blocks += [make(:void, else_tag)]
                # Clear cached descendants
                remove_instance_variable(:@all_descendants)
              end

              out "<% page_numbers(#{curr_page}, #{page_count}, #{(@params[:join] || ' ').inspect}, #{@params[:page_count] ? @params[:page_count].to_i : 'nil'}) do |#{page_number}, #{page_join}| %>"
              out "<%= #{page_join} %>"
              with_context(:node => node.move_to(page_number, Number)) do
                out expand_if("#{page_number} != #{curr_page}")
              end
              out "<% end -%>"
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

          # Return the HTTP verb to use for the given action.
          def http_method_from_action(action)
            case action
            when 'delete', 'unlink'
              'delete'
            when 'drop'
              'put'
            else
              'get'
            end
          end
      end # ZafuMethods
    end # Urls
  end # Use
end # Zena