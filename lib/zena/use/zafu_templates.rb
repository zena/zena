require 'zafu/controller_methods'

module Zena
  module Use
    module ZafuTemplates
      module Common

        # Return a template's content from an url. If the url does not start with a '/', we try by replacing the
        # first element with the current skin_name and if it does not work, we try with the full url. If the url
        # start with a '/' we use the full url directly.
        def get_template_text(path, base_path)
          return nil unless res = find_document_for_template(path, base_path)
          doc, base_path = res
          # text, fullpath (for recursion testing), base_path
          return doc.text, doc.fullpath, base_path
        end

        # Return the zen_path ('/en/image34.png') for an asset given its name ('img/footer.png').
        # The rule is not the same whether we are rendering a template and find <img/> <link rel='stylesheet'/> tags
        # or if we are parsing assets in a CSS file.
        def template_url_for_asset(opts)
          src = opts[:src]
          if src =~ /\A(.*)\.(\w+)\Z/
            src, format = $1, $2
          end

          if opts[:parse_assets]
            base_path = opts[:base_path] || ''
            base_path = base_path[1..-1] if base_path[0..0] == '/'

            if src =~ /\A(.*)_(\w+)\Z/
              # if the element was not found, maybe it was not a name with underscore but it was an image mode
              src2, mode2 = $1, $2
            end

            paths = []
            if src[0..0] == '/'
              paths << src[1..-1]
              paths << src2[1..-1] if src2
            else
              paths << (base_path + '/' + src)
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
            if src =~ /\A(.*)_(\w+)\Z/
              src, mode = $1, $2
            end

            src2 = opts[:src].split('/').map {|s| s.url_name!}.join('/')

            unless res = find_document_for_template(src, opts[:base_path])
              # '_...' did not mean mode but was an old name.
              mode = nil
              return nil unless res = find_document_for_template(src2, opts[:base_path])
            end

            asset, base_path = res
            self.renamed_assets[asset.fullpath] = asset
          end

          data_path(asset, :mode => mode)
        end



        # TODO: test
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
          if template_url =~ /\A\.|[^\w\+\._\-\/]/
            raise Zena::AccessViolation.new("'template_url' contains illegal characters : #{template_url.inspect}")
          end

          template_url = template_url[1..-1].split('/')
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
        def default_zafu_template(mode)
          if mode =~ /\A\.|[^\w\+\._\-\/]/
            raise Zena::AccessViolation.new("'mode' contains illegal characters : #{mode.inspect}")
          end
          File.read(File.join(Zena::ROOT, 'app', 'views', 'templates', 'defaults', "#{mode}.zafu"))
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
          @skins ||= {}
          self.expire_with_nodes ||= {}
          self.renamed_assets ||= {}

          skin = (@skins[skin_name] ||= secure(Skin) { Skin.find_by_name(skin_name) })
          return nil unless skin

          fullpath = (skin.fullpath.split('/') + url).join('/')

          unless document = self.expire_with_nodes[fullpath]
            unless document = secure(Document) { Document.find_by_path(fullpath) }
              document = secure(Document) { Document.first(:conditions => ['name = ? AND section_id = ?', url.last, skin.id]) }
              self.expire_with_nodes[document.fullpath] = document if document
            end
            self.expire_with_nodes[fullpath] = document if document
          end

          if document
            # Return document and base_path to document
            base_path = "#{([skin.name] + url[0..-2]).join('/')}"
            [document, base_path]
          else
            nil
          end
        end

      end # Common

      module ControllerMethods

        def self.included(base)
          base.send(:helper_attr, :skin_names, :expire_with_nodes, :renamed_assets)
          if base.respond_to?(:helper_method)
            base.send(:helper_method, :dev_mode?, :get_template_text, :template_url_for_asset)
          end
          base.send(:attr_accessor, :skin_names, :expire_with_nodes, :renamed_assets)
          base.send(:include, ::Zafu::ControllerMethods)
          # Needs to be inserted after Zafu::ControllerMethods since we overwrite get_template_text and such
          base.send(:include, Common)
        end

        # Return the path of a template for the given skin, mode and format. Compiles the zafu template if needed.
        def template_url(opts={})
          @skin     = opts[:skin] || @node.skin
          mode      = opts[:mode]
          format    = opts[:format] || 'html'
          klass     = @node.vclass

          # possible classes for the master template :
          klasses = []
          klass.kpath.split(//).each_index { |i| klasses << klass.kpath[0..i] }

          if mode && mode[0..0] == '+'
            # Only search all skins for special modes ?
            # FIXME: remove this when we have rescue laoding in place
            template = secure(Template) { Template.find(:first,
              :conditions => ["tkpath IN (?) AND format = ? AND mode #{mode ? '=' : 'IS'} ? AND template_indices.node_id = nodes.id", klasses, format, mode],
              :from       => "nodes, template_indices",
              :select     => "nodes.*, (template_indices.skin_id = #{@skin.id}) AS skin_ok",
              :order      => "length(tkpath) DESC, skin_ok DESC"
            )}

            if template && template.skin_id != @skin.id
              @skin = template.skin
            end

          else
            template = secure(Template) { Template.find(:first,
              :conditions => ["tkpath IN (?) AND format = ? AND mode #{mode ? '=' : 'IS'} ? AND template_indices.node_id = nodes.id AND template_indices.skin_id = ?", klasses, format, mode, @skin.id],
              :from       => "nodes, template_indices",
              :select     => "nodes.*",
              :order      => "length(tkpath) DESC"
            )}
          end

          # FIXME use a default fixed template.
          raise ActiveRecord::RecordNotFound unless template

          lang_path = dev_mode? ? "dev_#{lang}" : lang

          # Path as seen from zafu:
          zafu_url  = template.fullpath.gsub(/^#{@skin.fullpath}/,"/#{@skin.name}")

          rel_path  = current_site.zafu_path + "/#{zafu_url}/#{lang_path}/_main.erb"
          path      = SITES_ROOT + rel_path

          if !File.exists?(path) || params[:rebuild]
            rebuild_template(template, zafu_url, rel_path)
          end

          return rel_path
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

        def dev_mode?
          session[:dev]
        end

        private
          # Return the node_context to use in zafu compilation from the current controller and action
          def get_node_context
            if self.class.to_s =~ /\A([A-Z]\w+?)s?[A-Z]/
              ivar = "@#{$1.downcase}"
              if var = self.instance_variable_get(ivar.to_sym)
                name  = ivar
                klass = var.class
              elsif var = self.instance_variable_get(ivar + 's')
                name = ivar + 's'
                klass = [var.first.class]
              end
              return ::Zafu::NodeContext.new(name, klass) if name
            end

            raise Exception.new("Could not guess node context from request parameters, please add something like \"zafu_node('@var_name', Page)\" in your action.")
          end

          # Build or rebuild a template based on a template, a zafu url ('/skin/path/to/template') and
          # a filesystem path inside SITES_ROOT where the built template should be compiled.
          def rebuild_template(template, zafu_url, rel_path)
            # clear :
            FileUtils::rmtree(File.dirname(SITES_ROOT + rel_path))

            @skins = {
              @skin.name => @skin
            }

            # Cache loaded templates and skins
            self.expire_with_nodes = {
              template.fullpath => template,
              @skin.fullpath    => @skin,
            }

            self.renamed_assets = {}

            begin
              res = ZafuCompiler.new_with_url(zafu_url, :helper => zafu_helper).to_erb(:dev => dev_mode?, :node => get_node_context)
           #rescue => err
           #  puts err.message
           #  puts err.backtrace.join("\n")
           #  return nil
            end

            # unless valid_template?(res, opts)
            #   # problem during rendering, use default zafu
            #   res = ZafuCompiler.new(default_zafu_template(mode), :helper => zafu_helper).render(:dev => dev_mode?)
            # end

            if dev_mode? && mode != '+popupLayout'
              # add template edit buttons
              if res =~ /<\/body>/
                res.sub!('</body>', "#{dev_box}<%= render_js %></body>")
              else
                res << dev_box
              end
            else
              res.sub!('</body>', "<%= render_js %></body>")
            end

            secure!(CachedPage) { CachedPage.create(
              :path            => rel_path,
              :expire_after    => nil,
              :expire_with_ids => self.expire_with_nodes.values.map{|n| n[:id]}.uniq,
              :node_id         => template[:id],
              :content_data    => res) }
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
              res << "  <li><a class='group' onclick='$(\"_dev_#{name}\").toggle();' href='#'>#{name}</a>\n"
              res << "  <table id='_dev_#{name}'#{name == 'images' ? " style='display:none;'" : ''}>\n"
              nodes.each do |k,n|
                res << "    <tr><td class='actions'>#{zafu_helper.send(:node_actions, :node=>n)}</td><td>#{zafu_helper.send(:link_to,k,zen_path(n))}</td></tr>\n"
              end
              res << "  </table>\n"
              res << "  </li>\n"
            end

            res << "  <li><a class='group' onclick='$(\"_dev_tools\").toggle();' href='#'>tools</a>\n"
            res << "    <ul id='_dev_tools' style='display:none;'>\n"
            res << "      <li><a href='?rebuild=true'>#{_('rebuild')}</a></li>\n"
            res << "<% if @node.kind_of?(Skin) -%>      <li><a href='<%= export_node_path(@node[:zip]) %>'>#{_('export')}</a></li>\n<% end -%>"
            res << "      <li><a href='/users/#{visitor[:id]}/swap_dev'>#{_('turn dev off')}</a></li>\n"
            res << "      <li>skins used: #{skin_names.join(', ')}</li>\n"
            res << "    </ul>\n  </li>\n</ul></div>"
            res
          end
      end # ControllerMethods

      module ViewMethods
        include Common
        include RubyLess
        safe_method :start => {:method => 'start_node', :class => Node}

        # main node before ajax stuff (the one in browser url)
        def start_node
          @start_node ||= if params[:s]
            secure(Node) { Node.find_by_zip(params[:s]) }
          else
            @node
          end
        end

        # list of page numbers links
        def page_numbers(current, count, join_string = nil, max_count = nil)
          max_count ||= 10
          join_string ||= ''
          join_str = ''
          if count <= max_count
            1.upto(count) do |p|
              yield(p, join_str)
              join_str = join_string
            end
          else
            # only first pages (centered around current page)
            if current - (max_count/2) > 0
              finish = [current + (max_count/2),count].min
            else
              finish = [max_count,count].min
            end

            start  = [finish - max_count + 1,1].max

            start.upto(finish) do |p|
              yield(p, join_str)
              join_str = join_string
            end
          end
        end

        # Group an array of records by key.
        def group_array(list)
          groups = []
          h = {}
          list.each do |e|
            key = yield(e)
            unless group_id = h[key]
              h[key] = group_id = groups.size
              groups << []
            end
            groups[group_id] << e
          end
          groups
        end

        def sort_array(list)
          list.sort do |a,b|
            va = yield([a].flatten[0])
            vb = yield([b].flatten[0])
            if va && vb
              va <=> vb
            elsif va
              1
            elsif vb
              -1
            else
              0
            end
          end
        end

        def min_array(list)
          list.flatten.min do |a,b|
            va = yield(a)
            vb = yield(b)
            if va && vb
              va <=> vb
            elsif va
              1
            elsif vb
              -1
            else
              0
            end
          end
        end

        def max_array(list)
          list.flatten.min do |a,b|
            va = yield(a)
            vb = yield(b)
            if va && vb
              vb <=> va
            elsif vb
              1
            elsif va
              -1
            else
              0
            end
          end
        end
      end # ViewMethods
    end # Zafu
  end # Use
end # Zena