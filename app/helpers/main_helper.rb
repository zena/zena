module MainHelper
  
  # Show a little [fr] next to the title if the desired language could not be found.
  def check_lang(obj)
    obj.v_lang != session[:lang] ? " <span class='wrong_lang'>[#{obj.v_lang}]</span> " : ""
  end
  
  # Used by edit_buttons
  def form_action(action, version_id=@item.v_id)
    if action == 'edit'
      "<a href='#' title='#{transb('btn_title_edit')}' onClick=\"editor=window.open('" + 
      url_for(:controller=>'version', :id=>version_id, :action=>'edit', :rnd=>salt_against_caching) + 
      "', 'editor', 'location=0,width=500,height=600');return false;\">" + transb('btn_edit') + "</a>"
    elsif action == 'view'
      tlink_to_remote('btn_view', :with=>'main', :url=>{:controller=>'version', :action=>'preview', :id=>version_id })
    elsif action == 'drive'
      tlink_to_remote('btn_drive', :with=>'main', :url=>{:controller=>'item', :action=>'drive', :version_id=>version_id, :rnd=>salt_against_caching })
    else
      tlink_to( "btn_#{action}", {:controller=>'version', :action => action , :id => version_id}, :title=>transb("btn_title_#{action}"), :post=>true ) + "\n"
    end
  end
  
  # Buttons are :edit, :add, :propose, :publish, :refuse, or :drive. :all = (:edit, :propose, :publish, :refuse, :drive)
  def edit_button(*args)
    res = []
    if args[0].kind_of?(Hash)
      action = args[0][:action]
      klass = args[0][:class]
    else
      action, klass = args
    end
    if (action == :edit or action == :all) && @item.can_edit?
      res << form_action('edit')
    end
    if action == :add && @item.can_write?
      case klass.to_s
      when 'Document'
        res << '<li id="add_document" style="display:block;" class="btn_add">'
        res << "<a href='#' onClick=\"uploader=window.open('#{url_for :controller=>"document", :action=>"new", :parent_id=>@item}', 'uploader', 'location=1,width=400,height=300');return false;\">#{ transb('btn_add_doc') }</a>"
        res << '</li>'
      when 'Page'
        res << render_to_string( :partial=>'base/add_page' )
      end
    end
    if (action == :propose or action == :all) && @item.can_propose?
      res << form_action('propose')
    end
    if (action == :publish or action == :all) && @item.can_publish_item?
      res << form_action('publish')
    end
    if (action == :refuse or action == :all) && @item.can_refuse?
      res << form_action('refuse')
    end
    if (action == :drive or action == :all) && @item.can_drive?
      res << form_action('drive')
    end
    res.join("\n")
  end
  
  # Create the traduction list for the current item
  def traductions(obj=@item)
    trad_list = []
    lang_found = false
    obj.traductions.map do |ed|
  		if ed == obj.v_lang
  		  lang_found = (ed == lang) # current item is in the requested lang
  			trad_list << "<span class='on'>" + link_to( ed, change_lang(ed)) + "</span>"
  		else
  			trad_list << "<span>" + link_to( ed, change_lang(ed)) + "</span>"
  		end
  	end
	  trad_list << "<span class='off'>#{lang}</span>" unless lang_found
	  trad_list
  end
  
  def change_lang(new_lang)
    if session[:user]
      {:overwrite_params => { :lang => new_lang }}
    else
      {:overwrite_params => { :prefix => new_lang }}
    end
  end
  
  # show author information
  def author(size=:small)
    if size == :large
      res = []
      res << "<div class='info'>"
      if  @item.author.id == @item.v_author.id
        res << trans("posted by") + " <b>" + @item.author.fullname + "</b>"
      else
        res << trans("original by") + " <b>" + @item.author.fullname + "</b>"
        res << trans("new post by") + " <b>" + @item.v_author.fullname + "</b>"
      end
      res << trans("on") + " " + short_date(@item.v_updated_at) + "."
      res << trans("Traductions") + " : <span id='trad'>" + traductions.join(", ") + "</span>"
      res << "</div>"
      res.join("\n")
    else
      "<div class='info'><b>#{@item.v_author.initials}</b> - #{short_date(@item.v_updated_at)}</div>"
    end
  end
  
  # show current path with links to ancestors
  def path_links(item=@item)
    path = item.fullpath
    current_path = []
    up = prefix
    nav = ["<a href='/#{up}'>#{ZENA_ENV[:site_name]}</a>"]
    path.each do |p| 
      current_path << p
      nav << "<a href='/#{up}/#{current_path.join('/')}'>#{p}</a>"
    end
    if item[:id] == @item[:id]
      res = "<ul id='path' class='path'>"
    else
      res = "<ul class='path'>"
    end
    res << "<li>#{nav.join(" / </li><li>")}</li></ul>"
  end

  # shows links to enable translation
  def translation_link(title=true)
    if session[:user] && session[:user][:groups].include?(ZENA_ENV[:translate_group])
      res  = title ? trans("Translate interface: ") : ''
      res += "<a href='/z/trans/list'>#{transb('list')}</a> : "
      res += session[:translate] ? "<a href='?translate=off'>#{transb('off')}</a>" : "<a href='?translate=on'>#{transb('_on')}</a>"
      res
    else
      ''
    end
  end

  # show language selector
  def lang_links
    if ZENA_ENV[:monolingual]
      ''
    else
      res = []
      ZENA_ENV[:languages].sort.each do |l|
        if l == lang
          res << "<b>#{l}</b>"
        else
          res << "<a href='?lang=#{l}'>#{l}</a>"
        end
      end
      if session[:translate]
        res << translation_link(false)
      end
      "<div id='lang'><span>#{res.join(' | ')}</span></div>"
    end
  end
  
  def lang_ajax_link
    if ZENA_ENV[:monolingual]
      ''
    else
      res = "<div id='lang'><span>" + link_to_remote( lang, :update=>'lang', :url=>{:controller => 'trans', :action=>'lang_menu'})
      if session[:translate]
        res << translation_link(false)
      end
      res << '</span></div>'
      res
    end
  end
  
  def yhash_for(obj)
    if obj.class.y_fields != []
      res = ["<table cellspacing='0'>"]
      obj.class.y_fields.each do |elem|
        res << "<tr><td class='key'>#{trans(elem)}</td> <td class='value'>#{obj.yhash[elem.to_sym]}</td></tr>"
      end
      res << "</table>"
      res.join("\n")
    else
      ""
    end
  end

end
