module Zena
  module Use
    module Zafu
      module Common

        # Return a template's content from an url. If the url does not start with a '/', we try by replacing the
        # first element with the current skin_name and if it does not work, we try with the full url. If the url
        # start with a '/' we use the full url directly.
        # tested in MainControllerTest
        def get_template_text(opts)
          return nil unless res = find_document_for_template(opts)
          doc, url = *res
          # TODO: could we use this for caching or will we loose dynamic context based loading ?
          self.expire_with_nodes[url] = doc
          text = dev_mode? ? doc.version.text : doc.version(true).text
          return text, url, doc
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
            current_folder = opts[:current_folder] || ''
            current_folder = current_folder[1..-1] if current_folder[0..0] == '/'

            if src =~ /\A(.*)_(\w+)\Z/
              # if the element was not found, maybe it was not a name with underscore but it was an image mode
              src2, mode2 = $1, $2
            end

            paths = []
            if src[0..0] == '/'
              paths << src[1..-1]
              paths << src2[1..-1] if src2
            else
              paths << (current_folder + '/' + src)
              paths << (current_folder + '/' + src2) if src2
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

            unless res = find_document_for_template(opts)
              # '_...' did not mean mode but was an old name.
              mode = nil
              return nil unless res = find_document_for_template(opts.merge(:src => src2))
            end

            asset, url = *res
            self.renamed_assets[url] = asset
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

        # TODO: test
        def fullpath_from_template_url(template_url=params[:t_url])
          if template_url =~ /\A\.|[^\w\+\._\-\/]/
            raise Zena::AccessViolation.new("'template_url' contains illegal characters : #{template_url.inspect}")
          end

          template_url = template_url[1..-1].split('/')
          path = "/#{template_url[0]}/#{template_url[1]}/#{dev_mode? ? "dev_#{lang}" : lang}/#{template_url[2..-1].join('/')}"

          "#{SITES_ROOT}/#{current_site.host}/zafu#{path}"
        end

        # Make sure some vital templates never get broken
        def valid_template?(content, opts)
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


        # opts should contain :current_template and :src. The source is a path like 'default/Node-+index'
        # ('skin/template/path'). If the path starts with a slash, the skin_name in the path is searched first. Otherwise,
        # the current skin is searched first.
        # <r:include template='Node'/>
        #   find: #{skin_path(main_skin)}/Node
        #
        # <r:include template='/default/Node'/>
        #   find: #{skin_path('default')}/Node
        #
        def find_document_for_template(opts)
          src    = opts[:src]
          if src =~ /\A(.*)\.(\w+)\Z/
            src, format = $1, $2
          end

          if src =~ /\A(.*)_(\w+)\Z/
            src, mode = $1, $2
          end

          folder = (opts[:current_folder] && opts[:current_folder] != '') ? opts[:current_folder].split('/') : []
          @skin ||= {}
          if src =~ /^\//
            # starts with '/' : look here first
            url = src[1..-1].split('/')
            name = url.shift
            skin_names_list = opts[:parse_assets] ? [name] : ([name] + (self.skin_names - [name]))
          else
            # does not start with '/' : look in current skin first
            url = folder + src.split('/')
            skin_names_list = opts[:parse_assets] ? [] : self.skin_names.dup
            if url.size > 1
              name = url.shift
              skin_names_list << name unless skin_names_list.include?(name)
            end
          end
          document = skin_name = nil
          [false, true].each do |rebuild_path|
            # try to find using cached fullpath first.
            skin_names_list.each do |skin_name|
              next unless skin = @skin[skin_name] ||= secure(Skin) { Skin.find_by_name(skin_name) }
              path = (skin.fullpath(rebuild_path).split('/') + url).join('/')
              break if document = secure(Document) { Document.find_by_path(path) }
            end
            break if document
          end
          if format == 'data' && document
            format = document.c_ext
          end
          return document ? [document, (([skin_name] + url).join('/') + (mode ? "_#{mode}" : '') + (format ? ".#{format}" : ''))] : nil
        end

      end # Common

      module ControllerMethods
        include Common

        def self.included(base)
          base.send(:helper_attr, :skin_names, :expire_with_nodes, :renamed_assets)
          base.send(:helper_method, :dev_mode?) if base.respond_to?(:helper_method)
          base.send(:attr_accessor, :skin_names, :expire_with_nodes, :renamed_assets)
        end

        # Find the best template for the current node's skin, node's class, format and mode. The template
        # files are searched first into 'sites/shared/views/templates/fixed'. If the templates are not found
        # there, they are searched in the database and compiled into 'app/views/templates/compiled'.
        def template_url(opts={})
          @skin_name = opts[:skin]   || (@node ? @node[:skin] : nil) || 'default'
          @skin_name = @skin_name.url_name # security
          mode      = opts[:mode]
          format    = opts[:format] || 'html'
          klass     = @node.vclass

          # possible classes for the master template :
          klasses = []
          klass.kpath.split(//).each_index { |i| klasses << klass.kpath[0..i] }

          # FIXME: is searching in all skins a good idea ? I think not. Only searching for special modes '+popupLayout', '+login', etc.
          if mode && mode[0..0] == '+'
            template = secure(Template) { Template.find(:first,
              :conditions => ["tkpath IN (?) AND format = ? AND mode #{mode ? '=' : 'IS'} ? AND template_contents.node_id = nodes.id", klasses, format, mode],
              :from       => "nodes, template_contents",
              :select     => "nodes.*, template_contents.skin_name, template_contents.klass, (template_contents.skin_name = #{@skin_name.inspect}) AS skin_ok",
              :order      => "length(tkpath) DESC, skin_ok DESC"
            )}
          else
            template = secure(Template) { Template.find(:first,
              :conditions => ["tkpath IN (?) AND format = ? AND mode #{mode ? '=' : 'IS'} ? AND template_contents.node_id = nodes.id AND template_contents.skin_name = ?", klasses, format, mode, @skin_name],
              :from       => "nodes, template_contents",
              :select     => "nodes.*, template_contents.skin_name, template_contents.klass",
              :order      => "length(tkpath) DESC"
            )}
          end

          # FIXME use a default fixed template.
          raise ActiveRecord::RecordNotFound unless template

          lang_path = dev_mode? ? "dev_#{lang}" : lang

          skin_path = "/#{@skin_name}/#{template[:name]}"
          fullpath  = skin_path + "/#{lang_path}/_main.erb"
          rel_path  = current_site.zafu_path + fullpath
          path      = SITES_ROOT + rel_path

          if !File.exists?(path) || params[:rebuild]
            # no template ---> render
            # clear :
            # TODO: we should remove info in cached_page for _main
            FileUtils::rmtree(File.dirname(path))

            # set the places to search for the included templates
            # FIXME: there might be a better way to do this. In a hurry, fix later.
            @skin       = {}
            self.skin_names = [@skin_name]
            secure!(Skin) { Skin.find(:all, :order=>'position ASC, name ASC') }.each do |s|
              @skin[s.name] = s
              next if s.name == @skin_name # do not add it twice
              skin_names << s.name
            end
            self.expire_with_nodes = {}
            self.renamed_assets    = {}

            res = ZafuParser.new_with_url(skin_path, :helper => zafu_helper).render(:dev => dev_mode?)

            unless valid_template?(res, opts)
              # problem during rendering, use default zafu
              res = ZafuParser.new(default_zafu_template(mode), :helper => zafu_helper).render(:dev => dev_mode?)
            end

            if dev_mode? && mode != '+popupLayout'
              # add template edit buttons
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

              dev_box = "<div id='dev'><ul>\n"
              used_nodes.each do |name, nodes|
                dev_box << "  <li><a class='group' onclick='$(\"_dev_#{name}\").toggle();' href='#'>#{name}</a>\n"
                dev_box << "  <table id='_dev_#{name}'#{name == 'images' ? " style='display:none;'" : ''}>\n"
                nodes.each do |k,n|
                  dev_box << "    <tr><td class='actions'>#{zafu_helper.send(:node_actions, :node=>n)}</td><td>#{zafu_helper.send(:link_to,k,zen_path(n))}</td></tr>\n"
                end
                dev_box << "  </table>\n"
                dev_box << "  </li>\n"
              end

              dev_box << "  <li><a class='group' onclick='$(\"_dev_tools\").toggle();' href='#'>tools</a>\n"
              dev_box << "    <ul id='_dev_tools' style='display:none;'>\n"
              dev_box << "      <li><a href='?rebuild=true'>#{_('rebuild')}</a></li>\n"
              dev_box << "<% if @node.kind_of?(Skin) -%>      <li><a href='<%= export_node_path(@node[:zip]) %>'>#{_('export')}</a></li>\n<% end -%>"
              dev_box << "      <li><a href='/users/#{visitor[:id]}/swap_dev'>#{_('turn dev off')}</a></li>\n"
              dev_box << "      <li>skins used: #{skin_names.join(', ')}</li>\n"
              dev_box << "    </ul>\n  </li>\n</ul></div>"
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
              :expire_with_ids => self.expire_with_nodes.values.map{|n| n[:id]},
              :node_id         => template[:id],
              :content_data    => res) }
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
      end # ControllerMethods

      module ViewMethods
        include Common

        # main node before ajax stuff (the one in browser url)
        def start_node
          @start_node ||= if params[:s]
            secure!(Node) { Node.find_by_zip(params[:s]) }
          else
            @node
          end
        end

        # default date used to filter events in templates
        def main_date
          # TODO: timezone for @date ?
          # .to_utc(_('datetime'), visitor.tz)
          @main_date ||= params[:date] ? DateTime.parse(params[:date]) : DateTime.now
        end

        # Return sprintf formated entry. Return '' for values eq to zero.
        def sprintf_unless_zero(fmt, value)
          value.to_f == 0.0 ? '' : sprintf(fmt, value)
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

        # TODO: test
        # display the title with necessary id and checks for 'lang'. Options :
        # * :link if true, the title is a link to the object's page
        #   default = true if obj is not the current node '@node'
        # * :project if true , the project name is added before the object title as 'project / .....'
        #   default = obj project is different from current node project
        # if no options are provided show the current object title
        def show_title(opts={})
          obj = opts[:node] || @node

          unless opts.include?(:link)
            # we show the link if the object is not the current node or when it is being created by zafu ajax.
            opts[:link] = (obj[:id] != @node[:id] || params[:t_url]) ? 'true' : nil
          end

          unless opts.include?(:project)
            opts[:project] = (obj.get_project_id != @node.get_project_id && obj[:id] != @node[:id])
          end

          title = opts[:text] || obj.version.title
          if opts[:project] && project = obj.project
            title = "#{project.name} / #{title}"
          end

          title += check_lang(obj) unless opts[:check_lang] == 'false'
          title  = "<span id='v_title#{obj.zip}'>#{title}</span>"

          if (link = opts[:link]) && opts[:link] != 'false'
            if link =~ /\A(\d+)/
              zip = $1
              obj = secure(Node) { Node.find_by_zip(zip) }
              link = link[(zip.length)..-1]
              if link[0..0] == '_'
                link = link[1..-1]
              end
            end
            if link =~ /\Ahttp/
              "<a href='#{link}'>#{title}</a>"
            else
              link_opts = {}
              if link == 'true'
                # nothing special for the link format
              elsif link =~ /(\w+\.|)data$/
                link_opts[:mode] = $1[0..-2] if $1 != ''
                if obj.kind_of?(Document)
                  link_opts[:format] = obj.c_ext
                else
                  link_opts[:format] = 'html'
                end
              elsif link =~ /(\w+)\.(\w+)/
                link_opts[:mode]   = $1
                link_opts[:format] = $2
              elsif !link.blank?
                link_opts[:mode]   = link
              end
              "<a href='#{zen_path(obj, link_opts)}'>#{title}</a>"
            end
          else
            title
          end
        end
      end # ViewMethods
    end # Zafu
  end # Use
end # Zena