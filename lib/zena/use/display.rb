module Zena
  module Use
    module Display
      module Common
        def icon_finder
          if rel = RelationProxy.find_by_role('icon')
            finder = 'icon or image'
          else
            finder = 'image'
          end
          "#{finder} group by id,l_id order by l_id desc, position asc, node_name asc"
        end
      end # Common

      module ImageTags
        include Common

        # This is used by _crop.rhtml
        def crop_formats(obj)
          buttons = ['jpg', 'png']
          ext = Zena::TYPE_TO_EXT[obj.c_conten_type]
          ext = ext ? ext[0] : obj.ext
          buttons << ext unless buttons.include?(ext)
          buttons.map do |e|
            "<input type='radio' name='node[crop][format]' value='#{e}'#{e==ext ? " checked='checked'" : ''}/> #{e} "
          end
        end

        # Display an image tag for the given node. If no mode is provided, 'full' is used. Options are ':mode', ':id', ':alt',
        # ':alt_src' and ':class'. If no class option is passed, the format is used as the image class. Example :
        # img_tag(@node, :mode=>'pv')  => <img src='/sites/test.host/data/jpg/20/bird_pv.jpg' height='80' width='80' alt='bird' class='pv'/>
        def img_tag(obj, opts={})
          return '' unless obj
          # try:
          # 1. tag on element data (Image, mp3 document)
          res = asset_img_tag(obj, opts)

          # 2. tag using alt_src data
          # FIXME: replace recompilation by executing the find here
          # alt_src = alt_src.kind_of?(String) ? Node.do_find(:first, alt_src) : alt_src
          if !res && alt_src = opts[:alt_src]
            if alt_src == 'icon'
              alt_src = icon_finder
            else
              alt_src = "#{alt_src.split(',').join(' or ')}"
            end

            if icon = obj.find(:first, alt_src)
              return img_tag(icon, opts.merge(:alt_src => nil))
            end
          end

          # 3. generic icon
          res ||= generic_img_tag(obj, opts)

          if res.kind_of?(Hash)
            out = "<img"
            [:src, :width, :height, :alt, :id, :class, :style, :border, :onclick].each do |k|
              next unless v = res[k]
              out << " #{k}='#{v}'"
            end
            out + "/>"
          else
            res
          end
        end

        # <img> tag definition to show an Image / mp3 document
        # FIXME: this should live inside zafu
        def asset_img_tag(obj, opts)
          if obj.kind_of?(Image)
            res     = {}
            format  = Iformat[opts[:mode]] || Iformat['std']

            [:id, :border].each do |k|
              next unless opts[k]
              res[k]    = opts[k]
            end

            res[:alt]   = opts[:alt] || fquote(obj.title)
            res[:src]   = data_path(obj, :mode => (format[:size] == :keep ? nil : format[:name]), :host => opts[:host])
            res[:class] = opts[:class] || format[:name]

            # compute image size
            res[:width]  = obj.width(format)
            res[:height] = obj.height(format)
            if popup = format[:popup]

              if popup_fmt = Iformat[popup[:name]]
                options = popup[:options]
                keys    = popup[:show]
                res[:onclick] = 'Zena.popup(this)'
                res[:id]    ||= unique_id
                data = {}
                data['src'] = data_path(obj, :mode => (popup[:size] == :keep ? nil : popup[:name]), :host => opts[:host])
                data['width']   = obj.width(popup_fmt)
                data['height']  = obj.height(popup_fmt)

                data['fields'] = fields = {}
                data['keys']   = field_keys = []
                keys.each do |k|
                  case k
                  when 'navigation'
                    field_keys << k
                    data[k] = true
                  else
                    if v = obj.prop[k]
                      field_keys << k
                      case options[k]
                      when 'raw'
                        fields[k] = v
                      when 'link'
                        fields[k] = link_to(v, zen_path(obj))
                      else
                        fields[k] = zazen(v)
                      end
                    end
                  end
                end

                self.js_data << "$('#{res[:id]}')._popup = #{data.to_json};"
              end
            end
            res
          elsif obj.kind_of?(Document) && obj.ext == 'mp3' && (opts[:mode].nil? || opts[:mode] == 'std' || opts[:mode] == 'button')
            # rough wrap to use the 'button'
            # we differ '<object...>' by using a placeholder to avoid the RedCloth escaping.
            add_place_holder( %{ <object type="application/x-shockwave-flash"
              data="/images/swf/xspf/musicplayer.swf?&song_url=#{CGI.escape(data_path(obj))}"
              width="17" height="17">
              <param name="movie"
              value="/images/swf/xspf/musicplayer.swf?&song_url=#{CGI.escape(data_path(obj))}" />
              <img src="/images/sound_mute.png"
              width="16" height="16" alt="" />
            </object> } )
          end
        end

        # <img> tag definition for the generic icon (image showing class of element).
        def generic_img_tag(obj, opts)
          res = {}
          [:class, :id, :border, :style].each do |k|
            next unless opts[k]
            res[k] = opts[k]
          end

          if obj.vclass.kind_of?(VirtualClass) && !obj.vclass.icon.blank?
            # FIXME: we could use a 'zip' to an image as 'icon' (but we would need some caching to avoid multiple loading during doc listing)
            res[:src]     = obj.vclass.icon
            res[:alt]     = opts[:alt] || (_('%{type} node') % {:type => obj.vclass.name})
            res[:class] ||= obj.klass
            # no width, height available
            return res
          end

          # default generic icon from /images/ext folder
          res[:width]  = 32
          res[:height] = 32

          if obj.kind_of?(Document)
            name = obj.ext
            res[:alt] = opts[:alt] || (_('%{ext} document') % {:ext => name})
            res[:class] ||= 'doc'
          else
            name = obj.klass.downcase
            res[:alt] = opts[:alt] || (_('%{ext} node') % {:ext => obj.klass})
            res[:class] ||= 'node'
          end

          if !File.exist?("#{RAILS_ROOT}/public/images/ext/#{name}.png")
            name = 'other'
          end

          res[:src] = "/images/ext/#{name}.png"

          if opts[:mode] && (format = Iformat[opts[:mode]]) && format[:size] != :keep
            # resize image
            img = Zena::Use::ImageBuilder.new(:path=>"#{RAILS_ROOT}/public#{res[:src]}", :width=>32, :height=>32)
            img.transform!(format)
            if (img.width == res[:width] && img.height == res[:height])
              # ignore mode
              res[:mode] = nil
            else
              res[:width]  = img.width
              res[:height] = img.height

              new_file = "#{name}_#{format[:name]}.png"
              path     = "#{RAILS_ROOT}/public/images/ext/#{new_file}"
              unless File.exist?(path)
                # make new image with the mode
                if img.dummy?
                  File.cp("#{RAILS_ROOT}/public/images/ext/#{name}.png", path)
                else
                  File.open(path, "wb") { |f| f.syswrite(img.read) }
                end
              end

              res[:src] = "/images/ext/#{new_file}"
            end
          end

          res[:src] = "http://#{opts[:host]}#{res[:src]}" if opts[:host]

          res
        end
      end # ImageTags

      module ViewMethods
        include ImageTags
        include RubyLess
        safe_method  [:sprintf,     String, Number]                     => {:class => String, :method => 'sprintf'}
        safe_method  [:search_box,  {:ajax => String, :type => String}] => String
        safe_context [:admin_links, {:list => String}]                  => [String]

        # Return sprintf formated entry. Return '' for values eq to zero.
        def sprintf_unless_zero(fmt, value)
          value.to_f == 0.0 ? '' : sprintf(fmt, value)
        end

        # Display a search field
        def search_box(opts={})
          render_to_string(:partial=>'search/form', :locals => {:ajax => opts[:ajax], :type => opts[:type]})
        end

        # Return a list of administrative links
        def admin_links(opts = {})
          list = opts[:list] || 'all'
          if list == 'all'
            list = %w{home preferences comments users groups relations virtual_classes properties iformats sites dev}
          else
            list = list.split(',').map(&:strip)
          end

          list = list.map do |key|
            show_link(key)
          end.compact

          list.empty? ? nil : list
        end

        # shows links for site features
        def show_link(link, opt={})
          case link
          when 'home'
            return nil if visitor.is_anon?
            link_to_with_state(_('my home'), user_path(visitor))
          when 'preferences'
            return nil if visitor.is_anon?
            link_to_with_state(_('preferences'), preferences_user_path(visitor[:id]))
          when 'comments'
            return nil unless visitor.is_admin?
            link_to_with_state(_('manage comments'), comments_path)
          when 'users'
            return nil unless visitor.is_admin?
            link_to_with_state(_('manage users'), users_path)
          when 'groups'
            return nil unless visitor.is_admin?
            link_to_with_state(_('manage groups'), groups_path)
          when 'relations'
            return nil unless visitor.is_admin?
            link_to_with_state(_('manage relations'), relations_path)
          when 'virtual_classes'
            return nil unless visitor.is_admin?
            link_to_with_state(_('manage classes'), virtual_classes_path)
          when 'properties'
            return nil unless visitor.is_admin?
            link_to_with_state(_('manage properties'), columns_path)
          when 'iformats'
            return nil unless visitor.is_admin?
            link_to_with_state(_('image formats'), iformats_path)
          when 'sites'
            return nil unless visitor.is_admin?
            link_to_with_state(_('manage sites'), sites_path)
          when 'dev'
            return nil unless visitor.is_admin?
            if visitor.dev_skin_id
              link_to(_('turn dev off'), dev_skin_path)
            else
              link_to(_('turn dev on'), dev_skin_path('skin_id' => '0'))
            end
          else
            nil
          end
        end

=begin
        def title(node, opts = {})
          if node.kind_of?(Version)
            node = node.node
          end
          title_params = {}

          title_params[:check_lang] = @params[:check_lang] if @params.include?(:check_lang)

          if @params[:link]
            value, static = parse_attributes_in_value(@params[:link], :erb => false)
            link_param = ", :link=>\"#{value}\""
          else
            link_param = ''
          end

          res = "<%= show_title(:node=>#{node}#{link_param}#{params_to_erb(title_params)}"
          if @params[:text]
            res << ", :text=>#{@params[:text].inspect}"
          elsif @params[:attr]
            res << ", :text=>#{node_attribute(@params[:attr])}"
          end

          if @params.include?(:project)
            res << ", :project=>#{@params[:project] == 'true'}"
          end
          res << ")"
          if @params[:actions]
            res << " + node_actions(:node=>#{node}#{params_to_erb(:actions=>@params[:actions], :publish_after_save=>auto_publish_param)})"
          end
          res << "%>"
          res
        end
          # TODO: test
          # display the title with necessary id and checks for 'lang'. Options :
          # * :link if true, the title is a link to the object's page
          #   default = true if obj is not the current node '@node'
          # * :project if true , the project name is added before the object title as 'project / .....'
          #   default = obj project is different from current node project
          # if no options are provided show the current object title
          def title(obj, opts={})

            unless opts.include?(:link)
              # we show the link if the object is not the current node or when it is being created by zafu ajax.
              opts[:link] = (obj[:id] != @node[:id] || params[:t_url]) ? 'true' : nil
            end

            unless opts.include?(:project)
              opts[:project] = (obj.get_project_id != @node.get_project_id && obj[:id] != @node[:id])
            end

            title = opts[:text] || obj.title
            if opts[:project] && project = obj.project
              title = "#{project.name} / #{title}"
            end

            title += check_lang(obj) unless opts[:check_lang] == 'false'
            title  = "<span id='title#{obj.zip}'>#{title}</span>"

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
                    link_opts[:format] = obj.ext
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
      end
=end
      end # ViewMethods

      module ZafuMethods
        include Common
        include RubyLess

        safe_method [:zazen, String] => :r_zazen

        # Parse text with zazen helper
        def r_zazen(signature = nil)
          @markup.prepend_param(:class, 'zazen')
          if signature
            {
              :class  => String,
              :method => 'zazen',
              :accept_nil => true,
              :append_hash => {:node => ::RubyLess::TypedString.new(node(Node).to_s, :class => node(Node).klass)}
            }
          else
            method = get_attribute_or_eval
            "<%= zazen(#{method}, :node => #{node(Node)}) %>"
          end
        end

        def get_attribute_or_eval(use_string_block = true)
          if attribute = @params[:attr] || @params[:date]
            code = "this.#{attribute}"
          elsif code = @params[:eval]
          elsif text = @params[:text]
            code = "%Q{#{text}}"
          elsif use_string_block && @blocks.size == 1 && @blocks.first.kind_of?(String)
            return RubyLess::TypedString.new(@blocks.first.inspect, :class => String, :literal => @blocks.first)
          else
            return parser_error("Missing attribute/eval parameter")
          end

          RubyLess.translate(code, self)
        rescue RubyLess::Error => err
          parser_error(err.message, code)
        end

        # Display an attribute or RubyLess code
        def r_show
          if node.list_context?
            @context[:node] = node.move_to("#{node}.first", node.klass.first)
            return r_show
          elsif node.will_be?(String)
            return "<%= #{node} %>"
          end

          return nil unless method = get_attribute_or_eval

          klass = method.klass

          if klass.kind_of?(Array)
            res = show_string(method)
          elsif klass <= String
            res = show_string(method)
          elsif klass <= Number
            res = show_number(method)
          elsif klass <= Time
            res = show_time(method)
          else
            res = show_string(method)
          end

          res
        end

        # Insert javascript asset tags
        def r_javascripts
          if @params[:list] == 'all' || @params[:list].nil?
            list = %w{ prototype effects dragdrop tablekit window zena }
          else
            list = @params[:list].split(',').map{|e| e.strip}
          end
          helper.javascript_include_tag(*list)
        end

        # Insert stylesheet asset tags
        def r_stylesheets
          if @params[:list] == 'all' || @params[:list].nil?
            list = %w{ reset window zena code }
          else
            list = @params[:list].split(',').map{|e| e.strip}
          end
          list << {:media => @params[:media]} if @params[:media]
          helper.stylesheet_link_tag(*list)
        end

        # Used by zafu templates that act as layouts (adminLayout for example) to insert the content if present
        # or render.
        def r_content_for_layout
          "<% if content_for_layout = yield -%><%= content_for_layout %><% else -%>" +
          expand_with +
          "<% end -%>"
        end

        # Display the page's default title
        def r_title_for_layout
          "<% if @title_for_layout -%><%= @title_for_layout %><% elsif @node && !@node.new_record? -%><%= @node.rootpath %><% elsif @node.parent -%><%= @node.parent.rootpath %><% else -%>" +
          expand_with +
          "<% end -%>"
        end

        # Show html to add open a popup window to add a document.
        # TODO: inline ajax for upload ?
        def r_add_document
          return parser_error("only works with nodes (not with #{node.klass})") unless node.will_be?(Node)
          @markup.append_param(:class, 'btn_add')
          node = self.node.list_context? ? self.node.up : self.node
          res = "<%= node_action_link('add_doc', #{node})  %>"
          "<% if #{node}.can_write? -%>#{@markup.wrap(res)}<% end -%>"
        end

        # Find icon through a relation named 'icon' or use first image child
        def r_icon
          finder = build_finder(:first, icon_finder)
          expand_with_finder(finder)
        end

        # Display an image
        def r_img
          return unless node.will_be?(Node)

          if src = @params[:src]
            finder = ::RubyLess.translate(@params[:src], self) #build_finder(:first, @params[:src])
            return parser_error("invalid class (#{finder.klass})") unless finder.klass <= Node

            img = finder
          else
            img = node
          end

          mode = @params[:mode] || 'std'
          # FIXME: replace this call by something that integrates better with html_tag_params and such.
          res = "img_tag(#{img}, :mode=>#{mode.inspect}"
          [:class, :alt_src, :id, :border, :style].each do |k|
            res  += ", :#{k}=>#{@params[k].inspect}" if @params[k]
          end
          res += ", :host => #{@context["exp_host"]}" if @context["exp_host"]
          res += ")"
          if finder = @params[:link]
            finder = ::RubyLess.translate(finder, self)

            return parser_error("Invalid class (#{finder.klass})") unless finder.klass <= Node

            opts_str = @context["exp_host"] ? ", :host => #{@context["exp_host"]}" : ""

            "<a href='<%= zen_path(#{finder}#{opts_str}) %>'><%= #{res} %></a>"
          else
            "<%= #{res} %>"
          end
        end

        # Shows a 'made with Zena' link or logo. ;-) Thanks for using this !
        def r_zena
          if logo = @params[:logo]
            # FIXME
            case logo
            when 'tiny'
            else
            end
          else
            text = case @params[:type]
            when 'garden'
              _("a Zen garden")
            else
              _("made with Zena")
            end
            "<a class='zena' href='http://zenadmin.org' title='Zena <%= Zena::VERSION %>'>#{text}</a>"
          end
        end

        private
          def show_number(method)
            if fmt = @params[:format]
              begin
                # test argument
                sprintf(fmt, 123.45)
              rescue ArgumentError
                return parser_error("incorect format #{fmt.inspect}")
              end

              if fmt =~ /%[\d\.]*f/
                modifier = ".to_f"
              elsif fmt =~ /%[\d\.]*i/
                modifier = ".to_i"
              else
                modifier = ''
              end

              if @params[:zero] == 'hide'
                "<%= sprintf_unless_zero(#{fmt.inspect}, #{method}#{modifier}) %>"
              else
                "<%= sprintf(#{fmt.inspect}, #{method}#{modifier}) %>"
              end
            else
              "<%= #{method} %>"
            end
          end

          def show_string(method)
            "<%= #{method} %>"
          end

          def show_time(method)
            hash_arguments = []

            [:tz, :lang, :format].each do |key|
              next unless value = @params[key]
              hash_arguments << ":#{key} => #{RubyLess.translate_string(value, self)}"
            end

            if hash_arguments == []
              "<%= #{method} %>"
            else
              "<%= format_date(#{method}, #{hash_arguments.join(', ')}) %>"
            end
          end
      end
    end # Display
  end # Use
end # Zena