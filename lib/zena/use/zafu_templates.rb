require 'zafu/controller_methods'

module Zena
  module Use
    module ZafuTemplates
      module Common
        DEFAULT_PATH = %r{^\/?\$([\+\-\w\/]+)}
        DEFAULT_TEMPLATES_PATH = "#{Zena::ROOT}/app/views/zafu"

        # Return a template's content from an url. If the url does not start with a '/', we try by replacing the
        # first element with the current skin_name and if it does not work, we try with the full url. If the url
        # start with a '/' we use the full url directly.
        def get_template_text(path, base_path)
          if path =~ DEFAULT_PATH
            filepath = File.join(DEFAULT_TEMPLATES_PATH, "#{$1}.zafu")
            text = File.exist?(filepath) ? File.read(filepath) : nil
            return text, path, base_path
          elsif @skin.nil? && path == 'Node'
            filepath = File.join(DEFAULT_TEMPLATES_PATH, "default/#{path}.zafu")
            text = File.exist?(filepath) ? File.read(filepath) : nil
            return text, path, base_path
          elsif res = find_document_for_template(path, base_path)
            doc, base_path = res
            # text, fullpath (for recursion testing), base_path
            return doc.text, doc.fullpath, base_path, doc
          else
            nil
          end
        end

        # Return the zen_path ('/en/image34.png') for an asset given its name ('img/footer.png').
        # The rule is not the same whether we are rendering a template and find <img/> <link rel='stylesheet'/> tags
        # or if we are parsing assets in a CSS file.
        def template_url_for_asset(opts)
          source = opts[:src]
          if source =~ /\A(.*)\.(\w+)\Z/
            source, format = $1, $2
          end

          if opts[:parse_assets]
            base_path = opts[:base_path] || ''
            base_path = base_path[1..-1] if base_path[0..0] == '/'

            if source =~ /\A(.*)_(\w+)\Z/
              # if the element was not found, maybe it was not a name with underscore but it was an image mode
              src2, mode2 = $1, $2
            end

            paths = []
            if source[0..0] == '/'
              paths << source[1..-1]
              paths << src2[1..-1] if src2
            else
              paths << (base_path + '/' + source)
              paths << (base_path + '/' + src2) if src2
            end

            # make sure path elements are url_names
            paths.map! do |path|
              res = []
              path.split('/').each do |e|
                if e == '..'
                  res.pop
                else
                  res << e.url_name
                end
              end
              res.join('/')
            end

            if asset = secure(Document) { Document.find_by_path(paths[0]) }
            elsif src2 && (asset = secure(Document) { Document.find_by_path(paths[1]) })
              mode = mode2
            else
              return nil
            end
          else
            src2 = source.split('/').map {|s| s.url_name!}.join('/')

            if source =~ /\A(.*)_(\w+)\Z/
              source, mode = $1, $2
            end


            unless res = find_document_for_template(source, opts[:base_path])
              # '_...' did not mean mode but was an old name.
              mode = nil
              return nil unless res = find_document_for_template(src2, opts[:base_path])
            end

            asset, base_path = res
            self.renamed_assets[asset.fullpath] = asset
          end

          data_path(asset, :mode => mode)
        end

        # Callback to save an write an Ajax template to file.
        def save_erb_to_url(template, template_url)
          path = fullpath_from_template_url(template_url)
          path += ".erb" unless path =~ /\.\w+\Z/
          FileUtils.mkpath(File.dirname(path)) unless File.exists?(File.dirname(path))
          File.open(path, "wb") { |f| f.syswrite(template) }
          ""
        end

        # Return the full path from a template's url.
        # The expected url is of the form '/skin/Klass-mode/partial'
        def fullpath_from_template_url(template_url=params[:t_url])
          "#{SITES_ROOT}#{template_path_from_template_url(template_url)}"
        end

        # Return the template path without '.erb' extension in case we need to append '_form'
        # from a template's url. The expected url is of the form '/skin/Klass-mode/partial'
        def template_path_from_template_url(template_url=params[:t_url])
          if template_url =~ /\A\.|[^\w\+\._\-\/\$]/
            raise Zena::AccessViolation.new("'template_url' contains illegal characters : #{template_url.inspect}")
          end

          template_url = template_url.split('/')
          path = "/#{template_url[0]}/#{template_url[1]}/#{dev_mode? ? "dev_#{lang}" : lang}/#{template_url[2..-1].join('/')}"

          "/#{current_site.host}/zafu#{path}"
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
          elsif %w{+login +index +adminLayout +popupLayout +notFound}.include?(opts[:mode])
            zafu_url ="$default/Node-#{opts[:mode]}"
          elsif opts[:mode]
            raise ActiveRecord::RecordNotFound
          else
            zafu_url ="$default/Node"
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
        def find_document_for_template(src, base_path = nil)
          if src =~ /^\//
            # Starts with '/' : first part of the path is a Skin
            url = src[1..-1].split('/')
          else
            # does not start with '/' : look in current directory
            folder = base_path.blank? ? [] : base_path.split('/')
            url = folder + src.split('/')
          end

          skin_name = url.shift

          # TODO: can we move this initialization somewhere else ?
          self.expire_with_nodes ||= {}
          self.renamed_assets ||= {}

          return nil unless skin = get_skin(skin_name)

          fullpath = (skin.fullpath.split('/') + url).join('/')

          unless document = self.expire_with_nodes[fullpath]
            unless document = secure(Document) { Document.find_by_path(fullpath) }
              document = secure(Document) { Document.first(:conditions => ['node_name = ? AND section_id = ?', url.last, skin.id]) }
              self.expire_with_nodes[document.fullpath] = document if document
            end
            self.expire_with_nodes[fullpath] = document if document
          end

          if document
            # Return document and base_path to document
            base_path = "#{([skin.node_name] + url[0..-2]).join('/')}"
            [document, base_path]
          else
            nil
          end
        end

      end # Common

      module ControllerMethods

        def self.included(base)
          base.send(:helper_attr, :expire_with_nodes, :renamed_assets)
          if base.respond_to?(:helper_method)
            base.send(:helper_method, :dev_mode?, :lang_path, :rebuild_template, :get_template_text, :template_url, :template_url_for_asset, :zafu_helper)
          end
          base.send(:attr_accessor, :expire_with_nodes, :renamed_assets)
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
          klasses = []
          klass.kpath.split(//).each_index { |i| klasses << klass.kpath[0..i] }

          if @skin && template = secure(Template) { Template.find(:first,
              :conditions => ["tkpath IN (?) AND format = ? AND mode #{mode ? '=' : 'IS'} ? AND idx_templates.node_id = nodes.id AND idx_templates.skin_id = ?", klasses, format, mode, @skin.id],
              :from       => "nodes, idx_templates",
              :select     => "nodes.*, tkpath",
              :order      => "length(tkpath) DESC"
            )}


            # Path as seen from zafu:
            zafu_url  = template.fullpath.gsub(/^#{@skin.fullpath}/, @skin.node_name)

            rel_path  = current_site.zafu_path + "/#{zafu_url}/#{lang_path}/_main.erb"
            path      = SITES_ROOT + rel_path

            if !File.exists?(path) || params[:rebuild]
              if @node && klass = Node.get_class_from_kpath(template.tkpath)
                zafu_node('@node', Zena::Acts::Enrollable.make_class(klass))
              else
                nil
              end

              unless rebuild_template(template, opts.merge(:zafu_url => zafu_url, :rel_path => rel_path, :dev_mode => (dev_box?(mode, format))))
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
          !visitor.dev_skin_id.blank?
        end

        # Return true if we should display the dev box
        def dev_box?(mode, format)
          format == 'html' && mode != '+popupLayout' && dev_mode?
        end

        def lang_path
          dev_mode? ? "dev_#{lang}" : lang
        end

        # Return the skin to use depending on the current node and dev mode of the visitor.
        def get_skin(skin_name = nil)
          @skins ||= {}

          if skin_name.blank?
            skin_zip = visitor.is_admin? ? visitor.dev_skin_id.to_i : 0

            case skin_zip
            when User::RESCUE_SKIN_ID
              # rescue skin
              skin = nil
            when User::ANY_SKIN_ID
              # normal skin
              skin = @node.skin || @node.parent.skin
            else
              # find skin from zip
              skin = secure(Skin) { Skin.find_by_zip(skin_zip)}
            end
          elsif skin = @skins[skin_name]
            return skin
          else
            skin =secure(Skin) { Skin.find_by_node_name(skin_name)}
          end

          if skin
            @skins[skin.node_name] = skin
          end

          skin
        end

        private
          # Return the node_context to use in zafu compilation from the current controller and action.
          # FIXME: Use information on template target_class to get class !
          def get_node_context
            return zafu_context[:node] if zafu_context[:node]

            if self.class.to_s =~ /\A([A-Z]\w+?)s?[A-Z]/
              ivar = "@#{$1.downcase}"
              if var = self.instance_variable_get(ivar.to_sym)
                name  = ivar
                klass = Zena::Acts::Enrollable.make_class(var.class)
              elsif var = self.instance_variable_get(ivar + 's')
                name = ivar + 's'
                klass = [Zena::Acts::Enrollable.make_class(var.first.class)]
              end
              return Zafu::NodeContext.new(name, klass) if name
            end

            if defined?(@node)
              return Zafu::NodeContext.new('@node', Zena::Acts::Enrollable.make_class(Node))
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

            # Cache loaded templates and skins
            if template
              self.expire_with_nodes = {
                template.fullpath => template
              }
            end

            self.renamed_assets = {}

            res = ZafuCompiler.new_with_url(zafu_url, :helper => zafu_helper).to_erb(:dev => dev_mode?, :node => get_node_context)

            unless valid_template?(res, opts)
              # problem during rendering, use default zafu
              return nil
            end

            if insert_dev
              # add template edit buttons
              if res =~ /<\/body>/
                res.sub!('</body>', "#{dev_box}<%= render_js %></body>")
              else
                res << dev_box
              end
            else
              res.sub!('</body>', "<%= render_js %></body>")
            end

            if template
              secure!(CachedPage) { CachedPage.create(
                :path            => rel_path,
                :expire_after    => nil,
                :expire_with_ids => self.expire_with_nodes.values.map{|n| n[:id]}.uniq,
                :node_id         => template[:id],
                :content_data    => res) }
            else
              # Save the default template in the current site's zafu path
              filepath = "#{SITES_ROOT}#{rel_path}"
              FileUtils.mkpath(File.dirname(filepath))
              File.open(filepath, "wb+") { |f| f.write(res) }
            end
          end

          def dev_box
            used_nodes  = []
            zafu_nodes  = []
            image_nodes = []
            asset_nodes = []
            self.expire_with_nodes.merge(self.renamed_assets).each do |k, n|
              if n.kind_of?(Image)
                image_nodes << [k,n]
              elsif n.kind_of?(Template)
                zafu_nodes  << [k,n]
              else
                asset_nodes << [k,n]
              end
            end
            used_nodes << ['zafu',    zafu_nodes] unless zafu_nodes.empty?
            used_nodes << ['images', image_nodes] unless image_nodes.empty?
            used_nodes << ['assets', asset_nodes] unless asset_nodes.empty?

            res = "<div id='dev'><ul>\n"
            used_nodes.each do |name, nodes|
              res << "  <li><a class='group' onclick='$(\"dev_#{name}\").toggle();' href='#'>#{name}</a>\n"
              res << "  <table class='dev_pop' id='dev_#{name}'#{name == 'images' ? " style='display:none;'" : ''}>\n"
              nodes.each do |k,n|
                res << "    <tr><td class='actions'>#{zafu_helper.send(:node_actions, n)}</td><td>#{zafu_helper.send(:link_to,k,zen_path(n))}</td></tr>\n"
              end
              res << "  </table>\n"
              res << "  </li>\n"
            end

            res << "  <li><a class='group' onclick='$(\"dev_tools\").toggle();' href='#'>tools</a>\n"
            res << "    <ul class='dev_pop' id='dev_tools'><li>\n"
            res << %Q{    <div style='float:right'><% form_for(:user, visitor, :url => user_path(visitor), :html => { :method => :put }) do |f| %>
              <%= f.select(:dev_skin_id, dev_skin_options, {}, {:onchange => 'this.form.submit()'}) %> <input style='display:none;' type='submit' value='<%= _('validate') %>'/>
            <% end -%></div>}
            res << "      <a style='float:right; margin:0 8px;' href='?rebuild=true'>#{_('rebuild_btn')}</a>\n"
            res << "<% if @node.kind_of?(Skin) -%><a href='<%= export_node_path(@node[:zip]) %>'>#{_('export')}</a>\n<% end -%>"
            res << "      <a style='float:right' href='/dev_skin'>#{_('turn_dev_off_btn')}</a>\n"
            res << "    </li></ul>\n  </li>\n</ul></div>"
            res
          end
      end # ControllerMethods

      module ViewMethods
        include Common

        def dev_skin_options
          skins = secure(Skin) { Skin.all }

          [
            ['off',    nil ],
            ['any',    0   ],
          ] + skins.map {|s| [ s.node_name, s.zip ] } + [
            ['rescue', -1  ],
          ]
        end
      end # ViewMethods
    end # Zafu
  end # Use
end # Zena