require 'will_paginate'

module Zena
  module Use
    module HtmlTags

      module FormTags
        #TODO: test
      	# Return the list of groups from the visitor for forms
      	def form_groups
      	  @form_groups ||= Group.find(:all, :select=>'id, name', :conditions=>"id IN (#{visitor.group_ids.join(',')})", :order=>"name ASC").collect {|p| [p.name, p.id]}
        end

        #TODO: test
        # Return the list of possible templates
        def form_skins
          @form_skins ||= secure!(Skin) { Skin.find(:all, :order=>'node_name ASC') }.map {|r| [r.title, r.zip]}
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
            values = secure_write(Node) { Node.all(:order => :node_name, :conditions=>["kpath LIKE ?", "#{kpath}%"]) }.map do |record|
              [record.title, record.zip]
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
          update = "new Ajax.Updater('#{name_ref}', '/nodes/#{(node || @node).zip}/attribute?pseudo_id=' + this.value + '&attr=#{attribute}', {method:'get', asynchronous:true, evalScripts:true});"
          "<div class='select_id'><input type='text' size='8'#{input_id} name='#{obj}[#{sym}]' value='#{zip}' onChange=\"#{update}\" onKeyup=\"#{update}\"/>"+
          "<span class='select_id_name' id='#{name_ref}'>#{current}</span></div>"
        end

        # TODO: select_id should use 'check_exists'
        def check_exists(opts)
          watch  = opts[:watch] || 'node_title'
          name_ref = unique_id
          params = []

          # Filtering key
          key = 'name'
          params << "#{key}=' + this.value + '"

          # Attribute to display
          attribute = opts[:show] || 'short_path'
          params << "attr=#{attribute}"

          # Scoping
          if kpath  = opts[:kpath]
            params << "kpath=#{kpath}"
          end

          function_name = "check#{unique_id}"
          js_data << "#{function_name} = function(event) {
            new Ajax.Updater('#{name_ref}', '/nodes/#{(opts[:node] || @node).zip}/attribute?#{params.join('&')}', {method:'get', asynchronous:true, evalScripts:true});
          };"

          js_data << "$('#{watch}').check_exists = #{function_name};"
          js_data << "Event.observe('#{watch}', 'change', #{function_name});"
          js_data << "Event.observe('#{watch}', 'keyup', #{function_name});"

          "<span class='select_id_name' id='#{name_ref}'>#{opts[:current]}</span>"
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
            nav << link_to(obj.title, zen_path(obj, opts))
          end

          nav << "<a href='#{url_for(zen_path(node))}' class='current'>#{node.title}</a>"
          res = "#{res}#{open_tag}#{nav.join("#{close_tag}#{open_tag}#{join}")}#{close_tag}"
        end

      end # LinkTags

      module ViewMethods
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
      end # ViewMethods
    end # HtmlTags
  end # Use
end # Zena