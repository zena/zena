module MainHelper
  
  # Show a little [fr] next to the title if the desired language could not be found.
  def check_lang(obj)
    obj.v_lang != session[:lang] ? " <span class='wrong_lang'>[#{obj.v_lang}]</span> " : ""
  end
  
  # Used by edit_buttons
  def form_action(action, version_id=nil)
    version_id ||= @item.v_id
    if action == 'edit'
      "<a href='#' title='#{transb('btn_title_edit')}' onClick=\"editor=window.open('" + 
      url_for(:controller=>'version', :id=>version_id, :action=>'edit', :rnd=>rnd) + 
      "', 'editor', 'location=0,width=500,height=600,resizable=1');return false;\">" + transb('btn_edit') + "</a>"
    elsif action == 'view'
      tlink_to_function('btn_view', "opener.Zena.version_preview(#{version_id}); return false;")
    elsif action == 'drive'
      "<a href='#' title='#{transb('btn_title_drive')}' onClick=\"editor=window.open('" + 
      url_for(:controller=>'item', :version_id=>version_id, :action=>'drive', :rnd=>rnd) + 
      "', 'editor', 'location=0,width=500,height=600,resizable=1');return false;\">" + transb('btn_drive') + "</a>"
    else
      tlink_to( "btn_#{action}", {:controller=>'version', :action => action , :id => version_id}, :title=>transb("btn_title_#{action}"), :post=>true ) + "\n"
    end
  end
  
  # Buttons are :edit, :add, :propose, :publish, :refuse, or :drive. :all = (:edit, :propose, :publish, :refuse, :drive)
  def edit_button(action, options={})
    res = []
    if options[:item]
      version_id = options[:item].v_id
      item = options[:item]
    else
      version_id = nil
      item = @item
    end
    if (action == :edit or action == :all) && item.can_edit?
      res << form_action('edit',version_id)
    end
    if (action == :propose or action == :all) && item.can_propose?
      res << form_action('propose',version_id)
    end
    if (action == :publish or action == :all) && item.can_publish?
      res << form_action('publish',version_id)
    end
    if (action == :refuse or action == :all) && item.can_refuse?
      res << form_action('refuse',version_id)
    end
    if (action == :drive or action == :all) && item.can_drive?
      res << form_action('drive',version_id)
    end
    "<li>#{res.join("</li>\n<li>")}</li>"
  end
  
  # TODO: test
  # show actions on versions
  def version_actions(version, opt={})
    opt = {:action=>:all}.merge(opt)
    return "" unless version.kind_of?(Version)
    actions = []
    if opt[:action] == :view
      if (version.status != Zena::Status[:del]) ||  (version[:user_id] == visitor_id )
        actions << form_action('view', version[:id])
      end
    elsif opt[:action] == :all
      case version.status
      when Zena::Status[:pub]
        actions << form_action('unpublish',version[:id]) if @item.can_unpublish?
      when Zena::Status[:prop]
        actions << form_action('publish',version[:id])
        actions << form_action('refuse',version[:id])
      when Zena::Status[:prop_with]
        actions << form_action('publish',version[:id])
        actions << form_action('refuse',version[:id])
      when Zena::Status[:red]
        actions << form_action('edit',version[:id]) if version.user[:id] == visitor_id
        actions << form_action('publish',version[:id])
        actions << form_action('propose',version[:id])
        actions << form_action('remove',version[:id]) if version.user[:id] == visitor_id
      when Zena::Status[:rep]
        actions << form_action('edit',version[:id]) if @item.can_edit_lang?(version.lang)
        actions << form_action('publish',version[:id])
        actions << form_action('propose',version[:id])
      when Zena::Status[:rem]
        actions << form_action('edit',version[:id]) if @item.can_edit_lang?(version.lang)
        actions << form_action('publish',version[:id])
        actions << form_action('propose',version[:id])
      when Zena::Status[:del]
        if (version[:user_id] == session[:user][:id])
          actions << form_action('edit',version[:id]) if @item.can_edit_lang?(version.lang)
        end
      end
    end
    actions.join(" ")
  end
  
  # TODO: test
  def discussion_actions(discussion, opt={})
    opt = {:action=>:all}.merge(opt)
    return '' unless @item.can_drive?
    if opt[:action] == :view
      tlink_to_function('btn_view', "opener.Zena.discussion_show(#{discussion[:id]}); return false;")
    elsif opt[:action] == :all
      if discussion.open?
        link_to_remote( transb("img_open"),:with=>'discussions', :url=>{:controller=>'discussion', :action => 'close' , :id => discussion[:id]}, :title=>transb("btn_title_close")) + "\n"
      else                                                                   
        link_to_remote( transb("img_closed"),  :with=>'discussions', :url=>{:controller=>'discussion', :action => 'open', :id => discussion[:id]}, :title=>transb("btn_title_open")) + "\n"
      end +
      if discussion.can_destroy?                                                 
        link_to_remote( transb("btn_remove"), :with=>'discussions', :url=>{:controller=>'discussion', :action => 'remove', :id => discussion[:id]}, :title=>transb("btn_title_destroy")) + "\n"
      else
        ''
      end
    end
  end
  
  # TODO: test
  def css_edit(css_file = 'zen.css')
    str = <<ENDTXT
    <div id='css_edit'>
      <div id='css' onClick='cssUpdate()'></div>
      <script type="text/javascript">
      var c=0
      var t
      function timedCount()
      {
        var file = $('css_file').value
        if (c == '#'){
          c = '_'
        } else {
          c = '#'
        }
        document.getElementById('css_counter').innerHTML=c
        
        new Ajax.Request('/z/version/css_preview', {asynchronous:true, evalScripts:true, parameters:'css='+file});
        t=setTimeout("timedCount()",1000)
      }

      function stopCount()
      {
        clearTimeout(t)
      }

      </script>
      <form>
        <input type="button" value="Start CSS" onClick="timedCount()">
        <input type="button" value="Stop  CSS" onClick="stopCount()">
        <span id='css_counter'></span> <input type='text' id='css_file' name='css_file' value='#{css_file}'/>
      </form>
    </div>
    
ENDTXT
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
  
  # find the title partial for the current object or parameter
  def title_partial(obj=@item)
    klass = obj.class
    path = nil
    partial = nil
    while (partial == nil) && (klass != ActiveRecord::Base) do
      path = File.join(RAILS_ROOT,'app', 'views', klass.to_s.downcase, '_title.rhtml')
      if File.exist?(path)
        partial = "#{klass.to_s.downcase}/title"
        break
      end
      klass = klass.superclass
    end    
    partial || 'main/title'
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
          if session[:user]
            res << link_to(l, request.parameters.merge(:lang=>l))
          else
            res << link_to(l, request.parameters.merge(:prefix=>l))
          end
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

end
