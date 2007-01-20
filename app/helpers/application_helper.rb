# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  include Zena::Acts::SecureScope
  include Zena::Acts::SecureController::InstanceMethods
  
  # helpers to include clean javascript
  def javascript( string )
    javascript_start +
    string +
    javascript_end
  end
  
  def javascript_start
    "<script type=\"text/javascript\" language=\"javascript\" charset=\"utf-8\">\n// <![CDATA[\n"
  end
  
  def javascript_end
    "\n// ]]>\n</script>"
  end
  
  # Calendar seizure setup
  def uses_calendar
    if ZENA_ENV[:calendar_langs].include?(lang)
      l = lang
    else
      l = ZENA_ENV[:default_lang]
    end
    <<-EOL
    <script src="/calendar/calendar.js" type="text/javascript"></script>
    <script src="/calendar/calendar-setup.js" type="text/javascript"></script>
    <script src="/calendar/lang/calendar-#{lang}-utf8.js" type="text/javascript"></script>
    <link href="/calendar/calendar-brown.css" media="screen" rel="Stylesheet" type="text/css" />
    #{javascript_start}
    Calendar._TT["DEF_DATE_FORMAT"] = "#{transb('datetime')}";
    Calendar._TT["FIRST_DAY"] = #{transb('week_start_day')};
    #{javascript_end}
    EOL
  end
  
  # Date selection tool
	def date_box(obj, var, opts = {})
	  rnd_id = Time.now.to_i
	  defaults = {  :id=>"datef#{rnd_id}", :button=>"dateb#{rnd_id}", :display=>"dated#{rnd_id}" }
	  opts = defaults.merge(opts)
	  date = eval("@#{obj} ? @#{obj}.#{var} : nil") || Time.now
	  value = format_date(date,'datetime')
    if opts[:size] == 0
      fld = hidden_field obj, var, :id=>opts[:id] , :value=>value
    else
	    fld = text_field   obj, var, :id=>opts[:id] , :value=>value, :size=>opts[:size]
    end
		<<-EOL
<p class="date_box"><img src="/calendar/iconCalendar.gif" id="#{opts[:button]}"/>
#{fld}
	<script type="text/javascript">
    Calendar.setup({
        inputField     :    "#{opts[:id]}",      // id of the input field
        button         :    "#{opts[:button]}",  // trigger for the calendar (button ID)
        singleClick    :    true,
        showsTime      :    true
    });
</script></p>
		EOL
	end
  
  # Translate submit_tag
  def tsubmit_tag(*args)
    args[0] = trans(args[0],:edit=>false)
    submit_tag(*args)
  end
  
  # Translate link_to_remote
  def tlink_to_remote(*args)
    args[0] = trans(args[0],:edit=>false)
    link_to_remote(*args)
  end
  
  # Translate link_to_remote
  def tlink_to(*args)
    args[0] = trans(args[0],:edit=>false)
    link_to(*args)
  end
  
  # Add class='on' if the link points to the current page
  def tlink_to_with_state(*args)
    title, url, options = *args
    options ||= {}
    same = true
    url.each do |k,v|
      same &&= (params[k.to_s] == v.to_s)
    end
    if same
      options[:class] = 'on'
    end
    tlink_to(title, url, options)
  end
  
  # Translate link_to_remote
  def tlink_to_function(*args)
    args[0] = trans(args[0],:edit=>false)
    link_to_function(*args)
  end
  
  # Translate links/button (not editable)
  def transb(key)
    trans(key, :edit=>false)
  end
  
  # creates a pseudo random string to avoid browser side ajax caching
  def rnd
    Time.now.to_i
  end

  # "Translate" static text into the current lang
  def trans(keyword, opt={})
    opt = {:edit=>true}.merge(opt)
    if opt[:translate] || (session[:translate] && opt[:edit])
      key = TransPhrase.translate(keyword)
      "<div id='phrase#{key[:id]}' class='trans'>" + 
      link_to_remote(key.into(lang), 
          :update=>"phrase#{key[:id]}", 
          :url=>{:controller=>'trans', :action=>'edit', :id=>key[:id]},
          :complete=>'$("trans_value").focus();$("trans_value").select()') +
      "</div>"
    else
      TransPhrase[keyword][lang]
    end
  end
  
  # Shows 'login' or 'logout' button.
  def login_link
    if session[:user]
      "<div id='logout'><a href='/logout'>#{transb('logout')}</a></div>"
    else
      "<div id='logout'><a href='/login'>#{transb('login')}</a></div>"
    end
  end
  
  # display the time with the format provided by the translation of 'long_time'
  def long_time(atime)
    format_date(atime, "long_time")
  end
  
  # display the time with the format provided by the translation of 'short_time'
  def short_time(atime)
    format_date(atime, "short_time")
  end
  
  # display the time with the format provided by the translation of 'full_date'
  def full_date(adate)
    format_date(adate, "full_date")
  end
  
  # display the time with the format provided by the translation of 'long_date'
  def long_date(adate)
    format_date(adate, "long_date")
  end
  
  # display the time with the format provided by the translation of 'short_date'
  def short_date(adate)
    format_date(adate, "short_date")
  end
  
  # format a date with the given format. Translate month and day names.
  def format_date(thedate, fmt)
    if thedate
      adate = visitor.tz.adjust(thedate)
      format = trans(fmt)
      if format != fmt
        # month name
        format.gsub!("%b", trans(adate.strftime("%b")) )
        format.gsub!("%B", trans(adate.strftime("%B")) )
        # weekday name
        format.gsub!("%a", trans(adate.strftime("%a")) )
        format.gsub!("%A", trans(adate.strftime("%A")) )
        adate.strftime(format)
      else
        trans fmt
      end
    end
  end
  
  # Show visitor name if logged in
  def visitor_link
    if session[:user]
      "<div id='visitor'>" + link_to( session[:user][:fullname], user_home_url ) + "</div>"
    else
      ""
    end
  end
  
  # Display flash[:notice] or flash[:error] if any. <%= flash <i>[:notice, :error, :both]</i> %>"
  def flash_messages(type=:both)
    "<div id='messages'>" +
    if (type == :notice || type == :both) && @flash[:notice]
      "<div id='notice' class='flash' onClick='new Effect.Fade(\"notice\")'>#{@flash[:notice]}</div>"
    else
      ''
    end + 
    if (type == :error  || type == :both) && @flash[:error ]
      "<div id='error' class='flash' onClick='new Effect.Fade(\"error\")'>#{@flash[:error]}</div>"
    else
      ''
    end +
    "</div>"
  end
  
  # Display logo with message (can be a date or a string)
  def logo(message='')
    if message.kind_of?(Time)
      message = format_date(message, 'logo_date')
    end
    "<div id='logo'>" +
    link_to( image_tag('/img/logo.png', :size=>'220x100'), :prefix => prefix, :controller => 'main', :action=>'index') +
    "<div id='logo_msg'>#{message}</div></div>"
  end
  
  # This method renders the Textile text contained in an object as html. It also renders the zena additions :
  # === Zena additions
  # all these additions are replaced by the traduction of 'unknown link' or 'unknown image' if the user does
  # not have read access to the linked node.
  # * ["":34] creates a link to node 34 with node's title.
  # * ["title":34] creates a link to node 34 with the given title.
  # * ["":034] if the node id starts with '0', creates a popup link.
  # * [!14!] inline image 14. (default format is 'std' defined in #ImageBuilder). Options are :
  # ** [!014!] inline image with 'pv' format
  # ** [!<.14!] or [!<14!] inline image surrounded with <p class='img_left'></p>
  # ** [!>.14!] or [!>14!] inline image surrounded with <p class='img_right'></p>
  # ** [!=.14!] or [!=14!] inline image with <p class='img_center'></p>
  # ** [!14.pv!] inline image transformed to format 'pv'. Formats are defined in #ImageBuilder.
  # ** all the options above can be used together as in [!>.14.med!] : inline image on the right, size 'med'.
  # ** [![2,3,5]!] gallery : inline preview with javascript inline viewer
  # ** [![]!] gallery with all images contained in the current node
  # * [!{7,9}!] documents listing for documents 7 and 9
  # * [!{}!] list all documents (with images) for the current node
  # * [!{d}!] list all documents (without images) for the current node
  # * [!{i}!] list all images for the current node
  # * [!14!:37] you can use an image as the source for a link
  # * [!14!:www.example.com] use an image for an outgoing link
  def zazen(text, opt={})
    opt = {:images=>true}.merge(opt)
    img = opt[:images]
    r = RedCloth.new(text) #, [:hard_breaks])
    r.gsub!(  /"([^"]*)":([0-9]+)/                    ) {|x| make_link(:title=>$1,:id=>$2)}
    r.gsub!(  /\!\[([^\]]*)\]\!/                      ) {|x| img ? make_gallery($1) : trans('[gallery]') }
    r.gsub!(  /\!\{([^\}]*)\}\!/                      ) {|x| img ? list_nodes($1)   : trans('[documents]')}
    r.gsub!(  /\!([^0-9]{0,2})([0-9]+)(\.([^\!]+)|)\!(:([^\s]+)|)/ ) {|x| img ? make_image(:style=>$1, :id=>$2, :size=>$4, :link=>$6) : trans('[image]')}
    r
    r.to_html
  end

  # Creates a link to the node referenced by id
  def make_link(opts)
    node = secure(Node) { Node.find(opts[:id]) }
    title = (opts[:title] && opts[:title] != '') ? opts[:title] : node.v_title
    if opts[:id][0..0] == '0'
      link_to title, {:prefix => prefix, :controller => 'main', :action=>'show', :path=>node.fullpath}, :popup=>true
    else
      link_to title, :prefix => prefix, :controller => 'main', :action=>'show', :path=>node.fullpath
    end
  rescue ActiveRecord::RecordNotFound
    "<span class='unknownLink'>#{trans('unknown link')}</span>"
  end
  
  # Create an img tag for the given image. See ApplicationHelper#zazen for details.
  def make_image(opts)
    id, style, size, link = opts[:id], opts[:style], opts[:size], opts[:link]
    if size
      size = IMAGEBUILDER_FORMAT[size] ? size : 'std'
    elsif id[0..0] == "0"
      size = 'pv'
    else
      size = nil
    end
    img = secure(Document) { Document.find(id) }
    
    style ||= ''
    case style.sub('.', '')
    when ">"
      prefix = "<p class='img_right'>"
      suffix = "</p>"
    when "<"
      prefix = "<p class='img_left'>"
      suffix = "</p>"
    when "="
      prefix = "<p class='img_center'>"
      suffix = "</p>"
    else
      prefix = suffix = ""
    end
    if img.kind_of?(Image)
      if size
        image = img.img_tag(size)
      else
        image = link_to(img.img_tag('std'), data_url(img))
      end
    else
      image = link_to(img.img_tag(size), data_url(img))
    end
      
    
    if link.nil?
      prefix + image + suffix
    elsif link =~ /^\d+$/
      prefix + make_link(:id=>link,:title=>image) + suffix
    else
      link = "http://#{link}" unless link =~ %r{.+://.+}
      prefix + "<a href='#{link}'>" + image + "</a>" + suffix
    end
  rescue ActiveRecord::RecordNotFound
    "<span class='unknownLink'>#{trans('unknown document')}</span>"
  end
  
  # Create a gallery from a list of images. See ApplicationHelper#zazen for details.
  def make_gallery(ids="")
    if ids == ""
      images = @node.images
    else
      ids = ids.split(',').map{|i| i.to_i}.join(',') # sql injection security
      images = secure(Document) { Document.find(:all, :conditions=>"id IN (#{ids})") }
    end
    render_to_string( :partial=>'main/gallery', :locals=>{:gallery=>images} )
  end

  def list_nodes(ids='')
    if ids == ""
      docs = @node.documents
    elsif ids == "d"
      docs = @node.documents_only
    elsif ids == "i"
      docs = @node.images
    else
      ids = ids.split(',').map{|i| i.to_i}.join(',') # sql injection security
      docs = secure(Document) { Document.find(:all, :order=>'name ASC', :conditions=>"id IN (#{ids})") }
    end
    render_to_string( :partial=>'main/list_nodes', :locals=>{:docs=>docs})
  end
  
  def data_url(obj)
    if obj.kind_of?(Document)
      {:controller=>'document', :action=>'data', :version_id=>obj.v_id, :filename=>obj.c_filename, :ext=>obj.c_ext}
    else
      raise StandardError, "Cannot create 'data_url' for #{obj.class}."
    end
  end
  
  # return a readable text version of a file size
  def fsize(size)
    size = size.to_f
    if size >= 1024 * 1024 * 1024
      sprintf("%.2f Gb", size/(1024*1024*1024))
    elsif size >= 1024 * 1024
      sprintf("%.1f Mb", size/(1024*1024))
    elsif size >= 1024
      sprintf("%i Kb", (size/(1024)).ceil)
    else
      sprintf("%i octets", size)
    end
  end
  
  # Hierachical menu. (same on all pages)
  def show_menu
    Cache.with(visitor_id, visitor_groups, Page.kpath, 'show_menu') do
      if ZENA_ENV[:menu_tag_id] !=nil
        menu  = secure(Tag) { Tag.find(ZENA_ENV[:menu_tag_id]) }
        menus = menu.pages
      elsif ZENA_ENV[:root_id] != nil
        menus = secure(Node) { Node.find(ZENA_ENV[:root_id]) }.pages
      else
        menus = secure(Page) { Page.find(:all, :conditions=>"parent_id IS NULL") }
      end
      res = ["<div id='menu'>"]
      res << "<ul>"
      res << render_to_string(:partial=>'main/menu', :collection=>menus)
      res << "</ul>"
      res << "</div>"
      res.join("\n")
    end
  end
  
  def calendar(options={})
    source = options[:from  ] || (@project ||= (@node ? @node.project : nil))
    date   = options[:date  ] || Date.today
    method = options[:find  ] || :notes
    size   = options[:size  ] || :tiny
    using  = options[:using ] || :event_at
    day_names, on_day = calendar_get_options(size, source, method)
    return "" unless on_day && source
    Cache.with(visitor_id, visitor_groups, 'NN', size, method, source.id, date.ajd, lang) do
      # find start and end date
      week_start_day = trans('week_start_day').to_i
      start_date  = Date.civil(date.year, date.mon, 1)
      start_date -= (start_date.wday + 7 - week_start_day) % 7
      end_date    = Date.civil(date.year, date.mon, -1)
      end_date   += (6 + week_start_day - end_date.wday) % 7
      
      # get list of notes in this scope
      # TODO: use time_zone here ?
      notes = source.send(method,:conditions=>["#{using} >= ? AND #{using} <= ?", start_date, end_date], :order=>"#{using} ASC")
      
      # build event hash
      calendar = {}
      notes.each do |n|
        calendar[n.send(using.to_sym).strftime("%Y-%m-%d")] ||= []
        calendar[n.send(using.to_sym).strftime("%Y-%m-%d")] << n
      end
  
      title = "#{trans(Date::MONTHNAMES[date.mon])} #{date.year}"
  
      head_day_names = []
      0.upto(6) do |i|
        head_day_names << "<td>#{trans(day_names[(i+week_start_day) % 7])}</td>"
      end
  
      content = []
      start_date.step(end_date,7) do |week|
        # each week
        content << "<tr class='body'>"
        week.step(week+6,1) do |day|
          # each day
          content << "<td#{ calendar_class(day,date)}#{day == Date.today ? " id='#{size}_today'" : "" }><p>#{on_day.call(calendar[day.strftime("%Y-%m-%d")], day)}</p></td>"
        end
        content << '</tr>'
      end
      
      render_to_string(:partial=>"calendar/#{size}", :locals=>{ :content=>content.join("\n"), 
                                                             :day_names=>head_day_names.join(""),
                                                             :title=>title, 
                                                             :date=>date,
                                                             :source=>source,
                                                             :method=>method,
                                                             :size=>size })
    end
  end
  
  def unless_empty(obj)
    if obj.nil? || obj.empty?
      return ''
    else
      yield(obj)
    end
  end
  
  # TODO: test
  def show(obj, sym, opt={})
    if opt[:as]
      key = "#{opt[:as]}#{obj.v_id}"
      method = opt[:as]
    else
      key = "#{sym}#{obj.v_id}"
      method = sym
    end
    if opt[:text]
      text = opt[:text]
    elsif [:v_text, :v_summary].include?(method)
      text = zazen(obj.send(sym), opt)
      klass = " class='text'"
    else
      text = obj.send(sym)
      klass = ""
    end
    if opt[:as]
      render_to_string :partial=>'node/show_attr', :locals=>{:id=>obj[:id], :text=>text, :method=>method, :key=>key, :klass=>klass,
                                                           :key_on=>"#{key}#{Time.now.to_i}_on", :key_off=>"#{key}#{Time.now.to_i}_off"}
    else
      "<div id='#{key}'#{klass}>#{text}</div>"
    end
  end
  
  # TODO: test
  def link_box(obj, sym, opt={})
    # FIXME: SECURITY is there a better way to do this ?
    node = eval("@#{obj}")
    method = "#{sym}_for_form".to_sym
    role = node.class.role[sym.to_s]
    setter = sym.to_s.singularize
    if role[:unique]
      # unique
      res = [select_id(obj,"#{setter}_id", :class=>role[:klass], :include_blank=>true)]
    else
      # many
      if opt[:in]
        ids = opt[:in].map{|i| i.to_i}
        list = node.send(method, :conditions=>["nodes.id IN (#{ids.join(',')})"])
      else
        list = node.send(method)
      end
      res = list.inject([]) do |list, l|
        list << "<input type='checkbox' name='node[#{setter}_ids][]' value='#{l.id}' class='box' #{ l[:link_id] ? "checked='1' " : ""}/>#{l.name}"
        list
      end
    end
    if opt.include?(:title)
      if opt[:title].nil?
        title = ''
      else
        title = "<li><b>#{opt[:title]}</b></li>"
      end
    else
      title = "<li><b>#{trans(sym.to_s)}</b></li>"
    end
    "<ul class='link_box'>#{title}<li>#{res.join('</li><li>')}</li></ul>"
  end
  
  #TODO: test
	# Return the list of groups from the visitor for forms
	def form_groups
	  @form_groups ||= Group.find(:all, :select=>'id, name', :conditions=>"id IN (#{visitor_groups.join(',')})", :order=>"name ASC").collect {|p| [p.name, p.id]}
  end
  
  #TODO: test
  # Return the list of possible templates
  def form_templates
    return @form_templates if @form_templates
    @form_templates = []
    Dir.foreach(File.join(RAILS_ROOT, 'app', 'views', 'templates')) do |file|
      next unless file =~ /^([a-zA-Z0-9]+)\.rhtml$/
      next if ['index', 'not_found'].include?($1)
      @form_templates << $1
    end
    @form_templates
  end
  
  #TODO: test
  def site_tree(obj=nil)
    skip  = obj ? obj[:id] : nil
    base  = secure(Node) { Node.find(ZENA_ENV[:root_id]) }
    level = 0
    if obj.nil?
      klass = Node
    elsif obj.kind_of?(Document)
      klass = Node
    elsif obj.kind_of?(Note)
      klass = Project
    else
      klass = Page
    end
    tree = get_site_tree(skip,base,level)
    tree.reject! { |node| !(node[1][:kpath] =~ /^#{klass.kpath}/) }
    return [] unless tree
    tree.map {|p| ["  "*p[0] + p[1][:name], p[1][:id] ]}
  end
  
  #TODO: test
  def readers_for(obj=@node)
    readers = if obj.private? 
      trans('img_private')
    elsif [obj.rgroup_id,obj.pgroup_id,obj.user_id].include?(1)
      trans('img_public')
    else
      names = []
      names |= [obj.rgroup.name.limit(4)] if obj.rgroup
      names |= [obj.pgroup.name.limit(4)] if obj.pgroup
      names << obj.user.initials
      names.join(', ')
    end
    custom = obj.inherit != 1 ? "<span class='custom'>#{trans('img_custom_inherit')}</span>" : ''
    "#{custom} #{readers}"
  end
  private
  
  def calendar_get_options(size, source, method)
    case size
    when :tiny
      day_names = Date::ABBR_DAYNAMES
      on_day    = Proc.new { |e,d| e ? "<b class='has_note'>#{d.day}</b>" : d.day }
    when :large
      day_names = Date::DAYNAMES
      on_day    = Proc.new do |notes,d|
        if notes
          res = ["#{d.day}"]
          notes.each do |e| #largecal_preview
            res << "<div>" + link_to_remote(e.name.limit(14), 
                                  :update=>'largecal_preview',
                                  :url=>{:controller=>'note', :action=>'day_list', :id=>source[:id], :find=>method, 
                                  :date=>d, :selected=>e[:id] }) + "</div>"
          end
          res.join("\n")
        else
          d.day
        end
      end
    end
    [day_names, on_day]
  end
  
  def calendar_class(day, ref)
    case day.wday
    when 6
      s = "sat"
    when 0
      s = "sun"
    else
      s = ""
    end
    s+=  day.mon == ref.mon ? '' : 'other'
    s != "" ? " class='#{s}'" : ""
  end

  # This lets helpers render partials
  def render_to_string(*args)
    @controller.send(:render_to_string, *args)
  end
  
  # TODO: test
  def select_id(obj, sym, opt={})
    if ['Project', 'Tag', 'Contact'].include?(opt[:class].to_s)
      klass = opt[:class].kind_of?(Class) ? opt[:class] : eval(opt[:class])
      return select(obj,sym,  secure(klass) { klass.find(:all, :select=>'id,name', :order=>'name ASC') }.map{|r| [r[:name], r[:id]]}, { :include_blank => opt[:include_blank] })
    end
    # FIXME: SECURITY is there a better way to do this ?
    node = eval("@#{obj}")
    if node
      id = node.send(sym.to_sym)
      current_obj = secure(Node) { Node.find_by_id(id) } if id
    else
      id = ''
      current_obj = nil
    end
    name_ref = "#{obj}_#{sym}_name"
    attribute = opt[:show] || 'name'
    if current_obj
      current = current_obj.send(attribute.to_sym)
      if current.kind_of?(Array)
        current = current.join('/')
      end
    else
      current = ''
    end
    update = "new Ajax.Updater('#{name_ref}', '/z/node/attribute/' + this.value + '?attr=#{attribute}', {asynchronous:true, evalScripts:true});"
    "<div class='select_id'><input type='text' size='8' id='#{obj}_#{sym}' name='#{obj}[#{sym}]' value='#{id}' onChange=\"#{update}\"/>"+
    "<span class='select_id_name' id='#{name_ref}'>#{current}</span></div>"
  end
  
end
=begin

# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  include Zena::Acts::SecureScope
  include Zena::Acts::SecureController::InstanceMethods
  include ZenaGlobals
  uses_strips :base, :admin, :calendar
  
  # Overwrite error_messages_for to include translation
  def error_messages_for(object_name, options = {})
    options = options.symbolize_keys
    object = instance_variable_get("@#{object_name}")
    if object && !object.errors.empty?
      content_tag("div",
      content_tag("ul", object.errors.full_messages.collect { |msg| content_tag("li", t(msg)) }),
      "id" => options[:id] || "errorExplanation", "class" => options[:class] || "errorExplanation"
      )
    else
      ""
    end
  end
  
  
  
end

=end