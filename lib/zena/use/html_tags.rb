require 'will_paginate'

module Zena
  module Use
    module HtmlTags
      module ImageTags

        # This is used by _crop.rhtml
        def crop_formats(obj)
          buttons = ['jpg', 'png']
          ext = Zena::TYPE_TO_EXT[obj.c_conten_type]
          ext = ext ? ext[0] : obj.c_ext
          buttons << ext unless buttons.include?(ext)
          buttons.map do |e|
            "<input type='radio' name='node[c_crop][format]' value='#{e}'#{e==ext ? " checked='checked'" : ''}/> #{e} "
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
          if !res && alt_src = opts[:alt_src]
            if alt_src == 'icon'
              if icon = obj.icon
                return img_tag(icon, opts.merge(:alt_src => nil))
              end
            elsif icon = obj.find(:first, alt_src.split(','))
              # icon through alt_src relation
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
            content = obj.version.content
            format  = Iformat[opts[:mode]] || Iformat['std']

            [:id, :border].each do |k|
              next unless opts[k]
              res[k]    = opts[k]
            end

            res[:alt]   = opts[:alt] || fquote(obj.version.title)
            res[:src]   = data_path(obj, :mode => (format[:size] == :keep ? nil : format[:name]), :host => opts[:host])
            res[:class] = opts[:class] || format[:name]

            # compute image size
            res[:width]  = content.width(format)
            res[:height] = content.height(format)
            if popup = format[:popup]

              if popup_fmt = Iformat[popup[:name]]
                options = popup[:options]
                keys    = popup[:show]
                res[:onclick] = 'Zena.popup(this)'
                res[:id]    ||= unique_id
                data = {}
                data['src'] = data_path(obj, :mode => (popup[:size] == :keep ? nil : popup[:name]), :host => opts[:host])
                data['width']   = content.width(popup_fmt)
                data['height']  = content.height(popup_fmt)

                data['fields'] = fields = {}
                data['keys']   = field_keys = []
                keys.each do |k|
                  case k
                  when 'navigation'
                    field_keys << k
                    data[k] = true
                  else
                    if v = obj.safe_read(k)
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
          elsif obj.kind_of?(Document) && obj.version.content.ext == 'mp3' && (opts[:mode].nil? || opts[:mode] == 'std' || opts[:mode] == 'button')
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
            name = obj.version.content.ext
            res[:alt] = opts[:alt] || (_('%{ext} document') % {:ext => name})
            res[:class] ||= 'doc'
          else
            name = obj.klass.underscore
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

      module FormTags
        #TODO: test
      	# Return the list of groups from the visitor for forms
      	def form_groups
      	  @form_groups ||= Group.find(:all, :select=>'id, name', :conditions=>"id IN (#{visitor.group_ids.join(',')})", :order=>"name ASC").collect {|p| [p.name, p.id]}
        end

        #TODO: test
        # Return the list of possible templates
        def form_skins
          @form_skins ||= secure!(Skin) { Skin.find(:all, :order=>'name ASC') }.map {|r| r[:name]}
        end

        # Date selection tool
      	def date_box(obj, var, opts = {})
      	  rnd_id = rand(100000000000)
      	  defaults = {  :id=>"datef#{rnd_id}", :button=>"dateb#{rnd_id}", :display=>"dated#{rnd_id}" }
      	  opts = defaults.merge(opts)
      	  date = eval("@#{obj} ? @#{obj}.#{var} : nil")
      	  value = tformat_date(date,'datetime')
          if opts[:size]
            fld = "<input id='#{opts[:id]}' name='#{obj}[#{var}]' type='text' size='#{opts[:size]}' value='#{value}' />"
          else
            fld = "<input id='#{opts[:id]}' name='#{obj}[#{var}]' type='text' value='#{value}' />"
          end
      		<<-EOL
      <span class="date_box"><img src="/calendar/iconCalendar.gif" id="#{opts[:button]}" alt='#{_('date selection')}'/>
      #{fld}
      	<script type="text/javascript">
          Calendar.setup({
              inputField     :    "#{opts[:id]}",      // id of the input field
              button         :    "#{opts[:button]}",  // trigger for the calendar (button ID)
              singleClick    :    true,
              showsTime      :    true
          });
      </script></span>
      		EOL
      	end

        # Display an input field to select an id. The user can enter an id or a name in the field and the
        # node's path is shown next to the input field. If the :class option is specified and the elements
        # in this class are not too many, a select menu is shown instead (nodes in the menu are found using secure_write scope).
        # 'Sym' is the field to select the id for (parent_id, ...).
        def select_id(obj, sym, opt={})
          unless kpath = opt[:kpath]
            klass = opt[:class].kind_of?(Class) ? opt[:class] : Node.get_class(opt[:class] || 'Node')
            kpath = klass.kpath
          end

          count = secure_write(Node) { Node.count(:all, :conditions => ['kpath LIKE ?', "#{kpath}%"]) }
          if count == 0
            return select(obj, sym, [], {:include_blank => opt[:include_blank]})
          elsif count < 30
            values = secure_write(Node) { Node.all(:order=>:name, :conditions=>["kpath LIKE ?", "#{kpath}%"]) }.map do |record|
              [record['name'], record['zip']]
            end
            return select(obj, sym, values, { :include_blank => opt[:include_blank] })
          end

          if obj == 'link'
            if link = instance_variable_get("@#{obj}")
              node        = link.this
              current_obj = link.other
            end
          else
            unless id = opt[:id]
              node = instance_variable_get("@#{obj}")
              if node
                id = node.send(sym.to_sym)
              else
                id = nil
              end
            end

            if !id.blank?
              current_obj = secure!(Node) { Node.find(id) } rescue nil
            end
          end


          name_ref = unique_id
          attribute = opt[:show] || 'short_path'
          if current_obj
            zip = current_obj[:zip]
            current = current_obj.send(attribute.to_sym)
            if current.kind_of?(Array)
              current = current.join('/ ')
            end
          else
            zip = ''
            current = ''
          end
          input_id = opt[:input_id] ? " id='#{params[:input_id]}'" : ''
          # we use both 'onChange' and 'onKeyup' for old javascript compatibility
          update = "new Ajax.Updater('#{name_ref}', '/nodes/#{(node || @node).zip}/attribute?node=' + this.value + '&attr=#{attribute}', {method:'get', asynchronous:true, evalScripts:true});"
          "<div class='select_id'><input type='text' size='8'#{input_id} name='#{obj}[#{sym}]' value='#{zip}' onChange=\"#{update}\" onKeyup=\"#{update}\"/>"+
          "<span class='select_id_name' id='#{name_ref}'>#{current}</span></div>"
        end

        def unique_id
          @counter ||= 0
          "#{Time.now.to_i}_#{@counter += 1}"
        end

        #TODO: test
        def readers_for(obj=@node)
          readers = if obj.public?
            _('img_public')
          else
            names = []
            names |= [truncate(obj.rgroup.name, :length => 7)] if obj.rgroup
            names |= [truncate(obj.dgroup.name, :length => 7)] if obj.dgroup
            names << obj.user.initials
            names.join(', ')
          end
          custom = obj.inherit != 1 ? "<span class='custom'>#{_('img_custom_inherit')}</span>" : ''
          "#{custom} #{readers}"
        end

      end # FormTags

      module LinkTags
        include WillPaginate::ViewHelpers

        def protect_against_forgery?
          false
        end

        # Add class='on' if the link points to the current page
        def link_to_with_state(*args)
          title, url, options = *args
          options ||= {}
          if request.path == url
            options[:class] = 'on'
          end
          link_to(title, url, options)
        end

        #unobtrusive link_to_remote
        def link_to_remote(name, options = {}, html_options = {})
          html_options.merge!({:href => url_for(options[:url])}) unless options[:url].blank?
          super(name, options, html_options)
        end

        # only display first <a> tag
        def tag_to_remote(options = {}, html_options = {})
          url = url_for(options[:url])
          res = "<a href='#{url}' onclick=\"new Ajax.Request('#{url}', {asynchronous:true, evalScripts:true, method:'#{options[:method] || 'get'}'}); return false;\""
          html_options.each do |k,v|
            next unless [:class, :id, :style, :rel, :onclick].include?(k)
            res << " #{k}='#{v}'"
          end
          res << ">"
          res
        end

        # Show visitor name if logged in
        def visitor_link(opts={})
          unless visitor.is_anon?
            link_to( visitor.fullname, user_path(visitor) )
          else
            ""
          end
        end

        # TODO: rename 'admin_links' ?
        # shows links for site features
        def show_link(link, opt={})
          case link
          when :admin_links
            [show_link(:home), show_link(:preferences), show_link(:comments), show_link(:users), show_link(:groups), show_link(:relations), show_link(:virtual_classes), show_link(:iformats), show_link(:sites), show_link(:zena_up), show_link(:dev)].reject {|l| l==''}
          when :home
            return '' if visitor.is_anon?
            link_to_with_state(_('my home'), user_path(visitor))
          when :preferences
            return '' if visitor.is_anon?
            link_to_with_state(_('preferences'), preferences_user_path(visitor[:id]))
          when :comments
            return '' unless visitor.is_admin?
            link_to_with_state(_('manage comments'), comments_path)
          when :users
            return '' unless visitor.is_admin?
            link_to_with_state(_('manage users'), users_path)
          when :groups
            return '' unless visitor.is_admin?
            link_to_with_state(_('manage groups'), groups_path)
          when :relations
            return '' unless visitor.is_admin?
            link_to_with_state(_('manage relations'), relations_path)
          when :virtual_classes
            return '' unless visitor.is_admin?
            link_to_with_state(_('manage classes'), virtual_classes_path)
          when :iformats
            return '' unless visitor.is_admin?
            link_to_with_state(_('image formats'), iformats_path)
          when :sites
            return '' unless visitor.is_admin?
            link_to_with_state(_('manage sites'), sites_path)
          when :dev
            return '' unless visitor.is_admin?
            if @controller.session[:dev]
              link_to(_('turn dev off'), swap_dev_user_path(visitor))
            else
              link_to(_('turn dev on'), swap_dev_user_path(visitor))
            end
          else
            ''
          end
        end


        # show current path with links to ancestors
        def show_path(opts={})
          node = opts.delete(:node) || @node
          tag  = opts.delete(:wrap) || 'li'
          join = opts.delete(:join) || ''
          if tag != ''
            open_tag  = "<#{tag}>"
            close_tag = "</#{tag}>"
          else
            open_tag  = ""
            close_tag = ""
          end
          nav = []
          node.ancestors.each do |obj|
            nav << link_to(obj.name, zen_path(obj, opts))
          end

          nav << "<a href='#{url_for(zen_path(node))}' class='current'>#{node.name}</a>"
          res = "#{res}#{open_tag}#{nav.join("#{close_tag}#{open_tag}#{join}")}#{close_tag}"
        end

      end # LinkTags

      module ViewMethods
        include ImageTags
        include FormTags
        include LinkTags

        # Display flash[:notice] or flash[:error] if any. <%= flash <i>[:notice, :error, :both]</i> %>"
        def flash_messages(opts={})
          type = opts[:show] || 'both'
          "<div id='messages'>" +
          if (type == 'notice' || type == 'both') && flash[:notice]
            "<div id='notice' class='flash' onclick='new Effect.Fade(\"notice\")'>#{flash[:notice]}</div>"
          else
            ''
          end +
          if (type == 'error'  || type == 'both') && flash[:error ]
            "<div id='error' class='flash' onclick='new Effect.Fade(\"error\")'>#{flash[:error]}</div>"
          else
            ''
          end +
          "</div>"
        end

        # TODO: test
        def search_box(opts={})
          render_to_string(:partial=>'search/form', :locals => {:ajax => opts[:ajax], :type => opts[:type]})
        end


      end # ViewMethods
    end # HtmlTags
  end # Use
end # Zena