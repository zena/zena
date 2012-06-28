require 'zafu/controller_methods'

module Zena
  module Use
    module ZafuTemplates
      class AssetCache
        attr_accessor :used_assets

        def initialize
          @used_assets  = {'zafu' => [], 'images' => [], 'assets' => []}
          @cached_nodes = {}
          @used_assets['zafu'] = []
        end

        def cache_with_path(section_id, path)
          if cached = @cached_nodes[[section_id, path]]
            return cached
          else
            if document = yield
              if document.kind_of?(Template)
                @used_assets['zafu']   << [path, document]
              elsif document.kind_of?(Image)
                @used_assets['images'] << [path, document]
              else
                @used_assets['assets'] << [path, document]
              end
              @cached_nodes[[section_id, path]] = document
            else
              nil
            end
          end
        end

        def used_nodes
          @cached_nodes.values
        end
      end # DevBox


      module Common
        DEFAULT_PATH = %r{^\/?\$([\+\-\w\/]+)}
        DEFAULT_TEMPLATES_PATH = "#{Zena::ROOT}/app/views/zafu"

        # Return a template's content from an url. If the url does not start with a '/', we try by replacing the
        # first element with the current skin_name and if it does not work, we try with the full url. If the url
        # start with a '/' we use the full url directly.
        def get_template_text(path, section_id = nil, opts = {})
          if path =~ DEFAULT_PATH
            filepath = File.join(DEFAULT_TEMPLATES_PATH, "#{$1}.zafu")
            text = File.exist?(filepath) ? File.read(filepath) : nil
            return text, path, nil
          elsif @skin.nil? && path == 'Node'
            filepath = File.join(DEFAULT_TEMPLATES_PATH, "default/#{path}.zafu")
            text = File.exist?(filepath) ? File.read(filepath) : nil
            return text, path, nil
          else
            path = path.split('/').map {|s| String.from_filename(s) }
            if doc = find_document_for_template(path, section_id)
              # text, fullpath (for recursion testing), base_path
              return (doc.text || ''), doc.fullpath, doc.section_id, doc
            else
              nil
            end
          end
        end

        # Return the zen_path ('/en/image34.png') for an asset given its (urlencoded)
        # path ('img/footer.png').
        # The rule is not the same whether we are rendering a template and find <img/> <link rel='stylesheet'/> tags
        # or if we are parsing assets in a CSS file.
        def template_url_for_asset(opts)
          source = opts[:src]
          if source =~ /\A(.*)\.(\w+)\Z/
            source, format = $1, $2
          end

          if opts[:parse_assets]
            parent_id = opts[:parent].id

            if source =~ /\A(.*)_(\w+)\Z/
              # if the element was not found, maybe it was not a name with underscore but it was an image mode
              src2, mode2 = $1, $2
            end

            paths = []
            if source[0..0] == '/'
              # ignore parent
              parent_id = current_site.root_id
              paths << source[1..-1]
              paths << src2[1..-1] if src2
            else
              paths << source
              paths << src2 if src2
            end

            # Retrieve titles from urlencoding
            paths.map! do |path|
              res    = nil
              par_id = parent_id
              path.split('/').each do |e|
                if e == '..'
                  # forces absolute path
                  par_id = current_site.root_id
                  res ||= opts[:parent].fullpath_as_title
                  res.pop
                else
                  res ||= []
                  res << String.from_filename(e)
                end
              end
              [res, par_id]
            end

            if asset = secure(Document) { Document.find_by_path(*paths[0]) }
            elsif src2 && (asset = secure(Document) { Document.find_by_path(*paths[1]) })
              mode = mode2
            else
              return nil
            end
          else
            src2 = source.split('/').map {|s| String.from_filename(s) }

            if source =~ /\A(.*)_(\w+)\Z/
              source, mode = $1, $2
            end

            source = source.split('/').map {|f| String.from_filename(f) }

            unless asset = find_document_for_template(source, opts[:base_path])
              # '_...' did not mean mode but was an old name.
              mode = nil
              return nil unless asset = find_document_for_template(src2, opts[:base_path])
            end

          end

          data_path(asset, :mode => mode)
        end

        # Callback to save an write an Ajax template to file.
        def save_erb_to_url(template, template_url)
          path = fullpath_from_template_url(template_url, false)
          path += ".erb" unless path =~ /\.\w+\Z/
          FileUtils.mkpath(File.dirname(path)) unless File.exists?(File.dirname(path))
          File.open(path, "wb") { |f| f.syswrite(template) }
          ""
        end

        # Return the full path from a template's url.
        # The expected url is of the form '/skin/Klass-mode/partial'
        def fullpath_from_template_url(template_url=params[:t_url], build=false)
          "#{SITES_ROOT}#{template_path_from_template_url('',template_url,build)}"
        end

        # Make sure some vital templates never get broken
        def valid_template?(content, opts)
          #puts content
          mode = opts[:mode]
          case mode
          when '+login'
            content =~ %r{<form[^>]* action\s*=\s*./session}
          when '+adminLayout'
            content =~ %r{<%= content_for_layout %>} && %r{show_link(:admin_links)}
          else
            true
          end
        end

        # Default template content for a specified mode
        def default_template_url(opts = {})
          if opts[:format] && opts[:format] != 'html'
            raise ActiveRecord::RecordNotFound
          elsif %w{+login +index +adminLayout +popupLayout +notFound admin}.include?(opts[:mode])
            zafu_url =['$default', "Node-#{opts[:mode]}"].map(&:to_filename).join('/')
          elsif opts[:mode]
            raise ActiveRecord::RecordNotFound
          else
            zafu_url =['$default', 'Node'].map(&:to_filename).join('/')
          end

          # File path:
          rel_path  = current_site.zafu_path + "/#{zafu_url}/#{lang_path}/_main.erb"
          path      = SITES_ROOT + rel_path

          if !File.exists?(path)
            rebuild_template(nil, opts.merge(:zafu_url => zafu_url, :rel_path => rel_path, :dev_mode => (dev_mode? && opts[:mode] != '+popupLayout')))
          end

          rel_path
        end


        # Return a document for a given path and current directory. This method also returns
        # a new current_directory built from '/[skin name]/dirname/in/skin'
        # Search order for documents depends on the leading '/'.
        # With a leading slash "/joy/special/Node":
        # 1. Search for a Document with fullpath [joy skin fullpath]/special/Node
        # 2. Search anywhere in the skin for a document named "Node"
        # Without a leading slash "special/Node"
        # 1. Search for a Document with fullpath [current directory]/special/Node
        # 2. Search anywhere in the master skin for a document named 'Node'
        def find_document_for_template(src, section_id = nil)
          src = src.split('/') unless src.kind_of?(Array)

          if src[0] == ''
            # Starts with '/' : first part of the path is a Skin
            section_id = nil
            # remove blank
            src.shift
            # get skin
            return nil unless skin = get_skin(src.shift)
            section_id = skin.id
          elsif section_id.nil? && @skin
            section_id = @skin.id
            # does not start with '/' : look in current directory
          end

          self.asset_cache.cache_with_path(section_id, src) do
            unless document = secure(Document) { Document.find_by_path(src, section_id) }
              # find anywhere in Skin
              document = secure(Document) { Document.find_by_title(src.last, :conditions => ['section_id = ?', section_id]) }
            end
            document
          end
        end

        def zafu_node(name, klass)
          zafu_context[:node] = Zena::Use::NodeContext.new(name, klass)
        end
      end # Common

      module ControllerMethods

        def self.included(base)
#          base.send(:helper_attr, :asset_cache)
          if base.respond_to?(:helper_method)
            base.send(:helper_method, :dev_mode?, :lang_path, :rebuild_template, :get_template_text, :template_url, :template_url_for_asset, :zafu_helper, :template_path_from_template_url, :save_erb_to_url, :default_template_url, :fullpath_from_template_url)
          end

          base.send(:include, ::Zafu::ControllerMethods)
          # Needs to be inserted after Zafu::ControllerMethods since we overwrite get_template_text and such
          base.send(:include, Common)
        end

        # Return the path of a template for the given skin, mode and format. Compiles the zafu template if needed.
        def template_url(opts={})
          # opts[:skin] option removed
          @skin     = get_skin
          mode      = opts[:mode]
          format    = opts[:format] || 'html'
          klass     = @node.vclass

          # possible classes for the master template :
          kpaths = []
          klass.kpath.split(//).each_index { |i| kpaths << klass.kpath[0..i] }

          if @skin
            zafu_url, template = get_best_template(kpaths, format, mode, @skin)
            return default_template_url(opts) unless zafu_url
            
            rel_path  = current_site.zafu_path + "/#{zafu_url}/#{lang_path}/_main.erb"
            path      = SITES_ROOT + rel_path
            if !File.exists?(path) || params[:rebuild]
              if @node && klass = VirtualClass.find_by_kpath(template.tkpath)
                zafu_node('@node', klass)
              else
                nil
              end

              # template is a new record when template is returned for
              # a static file.
              unless rebuild_template(template.new_record? ? nil : template, opts.merge(:zafu_url => zafu_url, :rel_path => rel_path, :dev_mode => (dev_box?(mode, format))))
                return default_template_url(opts)
              end
            end

            rel_path
          else
            # No template found, use a default

            # $default/Node
            default_template_url(opts)
          end
        end

        # Find the best template to render the object.
        # The 'template' option is used when static calls the native
        # method to mangle the zafu_url
        def get_best_template(kpaths, format, mode, skin, template = nil)
          if template ||= secure(Template) { Template.find(:first,
              :conditions => ["tkpath IN (?) AND format = ? AND mode #{mode ? '=' : 'IS'} ? AND idx_templates.node_id = nodes.id AND idx_templates.skin_id = ?", kpaths, format, mode, skin.id],
              :from       => "nodes, idx_templates",
              :select     => "nodes.*, tkpath",
              :order      => "length(tkpath) DESC"
            )}

            # Path as seen from zafu:
            path_in_skin = template.fullpath.gsub(/^#{@skin.fullpath}\//, '')

            if path_in_skin == template.zip.to_s
              zafu_url = [@skin.title, template.title]
            else
              zafu_url = [@skin.title] + Node.fullpath_map(path_in_skin, :title)
            end
            [zafu_url.map(&:to_filename).join('/'), template]
          else
            nil
          end
        end

        # Return the template path from a template's url. The expected url is
        # of the form '/skin/Klass-mode/partial'
        def template_path_from_template_url(suffix='', template_url=params[:t_url], build=true)
          raise "Missing template_url (t_url parameter)" unless template_url
          if template_url =~ /\A\.|[^ #{String::ALLOWED_CHARS_IN_FILEPATH}]/
            raise Zena::AccessViolation.new("'template_url' contains illegal characters : #{template_url.inspect}")
          end

          template_url = template_url.split('/')
          base_p = ['', current_site.host, 'zafu'] + template_url[0..-2]
          lang_p = [dev_mode? ? "dev_#{lang}" : lang]
          part_p = template_url[-1]
          
          main_fullpath = SITES_ROOT + (base_p + lang_p + ['_main.erb']).join('/')
          if !File.exist?(main_fullpath) && build
            skin = template_url[0]
            template_name = template_url[-2]
            if template_name =~ ::Template::MODE_FORMAT_FROM_TITLE
              # title changed force  update
              klass  = $1
              mode   = $4 || ''
              format = $6 || 'html'
              # Template rendering node
              node_bak = @node
                # Find first node matching klass
                vclass = VirtualClass[klass]
                @node = Node.sfind("#{klass.underscore} in site", :first)
                if @node.skin.title != skin
                  @node.skin = secure(Skin) { Skin.find_by_title(skin) }
                end
                template_url(:mode => mode, :format => format)
              @node = node_bak
            end
          end
          
          (base_p + lang_p + ["#{part_p}#{suffix}.erb"]).join('/')
        end

        def zafu_helper
          @zafu_helper ||= begin
            # FIXME rails 3.0.pre: zafu_helper = ActionView::Base.for_controller(self)
            helper = ActionView::Base.new([], {}, self)
            helper.send(:_evaluate_assigns_and_ivars)
            helper.helpers.send :include, self.class.master_helper_module
            helper
          end
        end

        # Return true if the current rendering should include a dev box.
        def dev_mode?
          visitor.dev_mode?
        end

        # Return true if we should display the dev box
        def dev_box?(mode, format)
          (format == 'html' && !['+popupLayout', '+user'].include?(mode)) && dev_mode?
        end

        def lang_path
          dev_mode? ? "dev_#{lang}" : lang
        end

        # Return the skin to use depending on the current node and dev mode of the visitor.
        def get_skin(skin_name = nil)
          @skins ||= {}

          if skin_name.blank?
            skin = visitor.get_skin(@node)
          elsif skin = @skins[skin_name]
            return skin
          else
            skin =secure(Skin) { Skin.find_by_title(skin_name) }
          end

          if skin
            @skins[skin.title] = skin
          end

          skin
        end

        def asset_cache
          @asset_cache ||= AssetCache.new
        end

        private
          # Return the node_context to use in zafu compilation from the current controller and action.
          # FIXME: Use information on template target_class to get class !
          def get_node_context
            return zafu_context[:node] if zafu_context[:node]

            if self.class.to_s =~ /\A([A-Z]\w+?)s?[A-Z]/
              ivar = "@#{$1.downcase}"
              if var = instance_variable_get(ivar.to_sym)
                name  = ivar
                if var.kind_of?(Node)
                  klass = VirtualClass['Node'] # we could use $1
                else
                  klass = var.class
                end
              elsif var = self.instance_variable_get(ivar + 's')
                name = ivar + 's'
                if var.first.kind_of?(Node)
                  klass = [VirtualClass['Node']] # we could use $1
                else
                  klass = [var.class]
                end
              end

              return Zena::Use::NodeContext.new(name, klass) if name
            end

            if defined?(@node)
              return Zena::Use::NodeContext.new('@node', VirtualClass['Node'])
            else
              raise Exception.new("Could not guess node context from request parameters, please add something like \"zafu_node('@var_name', Page)\" in your action.")
            end
          end

          # Build or rebuild a template based on a template, a zafu url ('/skin/path/to/template') and
          # a filesystem path inside SITES_ROOT where the built template should be compiled.
          def rebuild_template(template, opts = {})
            zafu_url, rel_path, insert_dev = opts[:zafu_url], opts[:rel_path], opts[:dev_mode]

            # clear :
            FileUtils::rmtree(File.dirname(SITES_ROOT + rel_path))

            @asset_cache = AssetCache.new

            # Cache loaded templates and skins
            if template
              # Store template in expiry list and dev_box
              if fullpath = template.fullpath[/^#{@skin.fullpath}\/(.*)/,1]
                # absolute path with skin
                fullpath = [@skin.title] + template.fullpath_as_title(fullpath)
                self.asset_cache.cache_with_path(@skin.id, fullpath) do
                  template
                end
              end
            end

            res = ZafuCompiler.new_with_url(zafu_url, :helper => zafu_helper).to_erb(:dev => dev_mode?, :node => get_node_context, :master_template => template)

            unless valid_template?(res, opts)
              # problem during rendering, use default zafu
              return nil
            end

            if insert_dev
              # add template edit buttons
              if res =~ /<\/body>/
                res.sub!('</body>', "#{dev_box(template)}<%= render_js %></body>")
              else
                res << dev_box
              end
            else
              res.sub!('</body>', "<%= render_js %></body>")
            end
            
            if request.format == Mime::HTML
              # Insert start id
              res.sub!('<body', %Q{<body data-t='#{zafu_url}' data-z='<%= @node.zip %>' })
            end

            if template
              secure!(CachedPage) { CachedPage.create(
                :path            => rel_path,
                :expire_after    => nil,
                :expire_with_ids => self.asset_cache.used_nodes.map(&:id).uniq,
                :node_id         => template[:id],
                :content_data    => res) }
            else
              # Save the default template in the current site's zafu path
              filepath = "#{SITES_ROOT}#{rel_path}"
              FileUtils.mkpath(File.dirname(filepath))
              File.open(filepath, "wb+") { |f| f.write(res) }
            end
          end

          def dev_box(template = nil)
            used_nodes = self.asset_cache.used_assets

            res = "<div id='dev' class='devb'><ul>\n"
            used_nodes.each do |name, nodes|
              seen = {}
              nodes.reject! do |path, node|
                if seen[node.id]
                  true
                else
                  seen[node.id] = true
                  false
                end
              end
              next if nodes.empty?
              res << "  <li><a class='group' onclick='$(\"dev_#{name}\").toggle();' href='javascript:void(0)'>#{name}</a>\n"
              res << "  <table class='dev_pop' id='dev_#{name}'#{name == 'images' ? " style='display:none;'" : ''}>\n"
              if template && name == 'zafu'
                # Create specialized template on the fly for current page
                res << %Q{<tr><td colspan='2'><% if @node.kpath != #{template.tkpath.inspect} -%>
  <% _znode_dev = ::Template.new(:title => @node.klass, :parent_id => #{@skin.zip}) %>
  <% form_for(:node, _znode_dev, :url => nodes_path, :html => {:method => 'post', :id => 'zmake_template'}) do |f| %>
    <%= f.hidden_field(:parent_id) %>
    <%= f.hidden_field(:title) %>
    <%= f.hidden_field(:klass) %>
    <input type='hidden' name='redir' value='<%= request.path %>?rebuild=true'/>
    <b><a href='javascript:' onclick='$("zmake_template").submit();return false;'><img src='/images/add.png' title='create template for <%= @node.klass %>'/> create <%= @node.klass %>.zafu</a></b>
  <% end %>
<% end -%> #{node_action_link('add_doc', "#{@skin.zip}", :text => '')}</td></tr>}
              end
              nodes.each do |path, node|
                rel_path = node.fullpath.rel_path(node.section.fullpath)
                path = node.section.title + ' / ' + (secure(Node) { Node.fullpath_map(rel_path, :title)} || []).join(' / ')
                if node.kind_of?(Document)
                  path = path + ".#{node.ext}"
                end
                res << "    <tr><td class='actions'>#{zafu_helper.send(:node_actions, node)}</td><td>&nbsp;#{zafu_helper.send(:link_to, path, zen_path(node))}</td></tr>\n"
              end
              res << "  </table>\n"
              res << "  </li>\n"
            end

            res << "  <li><a class='group' onclick='$(\"dev_tools\").toggle();' href='javascript:void(0)'>tools</a>\n"
            res << "    <ul class='dev_pop' id='dev_tools'><li>\n"
            res << %Q{    <div style='float:right'><% form_for(:user, visitor, :url => user_path(visitor), :html => { :method => :put }) do |f| %>
              <p><%= f.select(:dev_skin_id, dev_skin_options, {}, {:onchange => 'this.form.submit()'}) %> <input style='display:none;' type='submit' value='<%= _('validate') %>'/></p>
            <% end %></div>}
            res << "      <a style='float:right; margin:0 8px;' href='?rebuild=true'>#{_('rebuild_btn')}</a>\n"
            res << "<% if @node.kind_of?(Skin) %><a href='<%= export_node_path(@node[:zip]) %>'>#{_('export')}</a>\n<% end %>"
            res << "      <a style='float:right' href='/dev_skin'>#{_('turn_dev_off_btn')}</a>\n"
            res << "    </li></ul>\n  </li>\n</ul></div>"
            res
          end
      end # ControllerMethods

      module ViewMethods
#        include Common

        def dev_skin_options
          skins = secure(Skin) { Skin.all }

          [
            ['off',    nil ],
            ['any',    0   ],
          ] + skins.map {|s| [ s.title, s.zip ] } + [
            ['rescue', -1  ],
          ]
        end
      end # ViewMethods
    end # Zafu
  end # Use
end # Zena