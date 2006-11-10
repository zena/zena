# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  
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
    <script src="/calendar/lang/calendar-#{l}-utf8.js" type="text/javascript"></script>
  	<link href="/calendar/calendar-brown.css" media="screen" rel="Stylesheet" type="text/css" />
  	EOL
  end
  
  # Translate submit_tag
  def tsubmit_tag(*args)
    args[0] = trans(args[0],false)
    submit_tag(*args)
  end
  
  # Translate link_to_remote
  def tlink_to_remote(*args)
    args[0] = trans(args[0],false)
    link_to_remote(*args)
  end
  
  # Translate link_to_remote
  def tlink_to(*args)
    args[0] = trans(args[0],false)
    link_to(*args)
  end
  
  # Translate link_to_remote
  def tlink_to_function(*args)
    args[0] = trans(args[0],false)
    link_to_function(*args)
  end
  
  # Translate links/button (not editable)
  def transb(key)
    trans(key, false)
  end
  
  # creates a pseudo random string to avoid browser side ajax caching
  def salt_against_caching
    self.object_id
  end

  # "Translate" static text into the current lang
  def trans(keyword, edit=true)
    key = TransKey.translate(keyword)
    if session[:translate] && edit # set wether untranslated text will be editable or not
      "<div id='translate_#{key[:id]}' class='translation'>" + 
      link_to_remote(key.into(lang), 
          :update=>"translate_#{key[:id]}", 
          :url=>"/z/trans/#{key[:id]}",
          :complete=>'$("translation_value").focus();$("translation_value").select()') +
      "</div>"
    else
      TransKey.translate(keyword).into(lang)
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
    format_date("long_time", atime)
  end
  
  # display the time with the format provided by the translation of 'short_time'
  def short_time(atime)
    format_date("short_time", atime)
  end
  
  # display the time with the format provided by the translation of 'long_date'
  def long_date(adate)
    format_date("long_date", adate)
  end
  
  # display the time with the format provided by the translation of 'short_date'
  def short_date(adate)
    format_date("short_date", adate)
  end
  
  # format a date with the given format. Translate month and day names.
  def format_date(fmt, adate)
    if adate
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
  
  # Parse date : return a date from a string
  def parse_date(str, fmt=trans("long_date"))
    if str =~ /\./
      elements = str.split('.')
      format = fmt.split('.')
    elsif str=~ /\-/
      elements = str.split('-')
      format = fmt.split('-')
    elsif str=~ /\//
      elements = str.split('/')
      format = fmt.split('/')
    end
    if elements
      hash = {}
      elements.each_index do |i|
        hash[format[i]] = elements[i]
      end
      hash['%Y'] ||= hash['%y'] ? (hash['%y'] + 2000) : nil
      if hash['%Y'] && hash['%m'] && hash['%d']
        Time.gm(hash['%Y'], hash['%m'], hash['%d'])
      else
        nil
      end
    else
      nil
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
  # test to here
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
  

  
  
  # This method renders the Textile[http://hobix.com/textile/] text contained in an object as html. It also renders the zena additions :
  # === Zena additions
  # ["":34] creates a link to item 34 with item's title. If the user does not have read access to item 34, the title is replaced by 'unknown'
  # ["":c3] creates a link to 'contact 3' with Contact#fullname as title. If the contact has a presentation page, links there.
  # ["title":c3] creates a link to contact 3 with the given title. If the contact has a presentation page, links there.
  # ["title":34] creates a link to item 34 with the given title. Replaced by 'unknown' if user does not have read access to the item linked.
  # [!36!] inline document 36. Replaced by nothing if user does not have read access to item 36.
  # [!036!] inline preview with popup for document 36. Replaced by nothing if user does not have read access to item 36.
  # [![2,3,5]!] gallery : inline preview with javascript inline viewer
  def z(str)
    r = RedCloth.new(str) #, [:hard_breaks])
    r.gsub!(/"([^"]+)":([0-9]+)/) {|x| makeLink($1,$2)}
    r.gsub!(/"":([0-9]+)/) {|x| makeLink(nil,$1)}
    r.gsub!(/\!\[([^\]]*)\]\!/) {|x| plug(:gallery, $1)}
    r.gsub!(/\!\{([^\]]*)\}\!/) {|x| makeDocs($1)}
    r.gsub!(/\!([^0-9]{0,2})([0-9]+)\!/) {|x| makeImage($2, $1,"")}
    r.gsub!(/\!([^0-9]{0,2})([0-9]*)\.([0-9]+)\!/) {|x| makeImage($2,$1,$3)}
    r
    r.to_html
  end
  
  
  
  # Create links for Zena additions to Textile
  def makeLink(title, theId)
    item = secure(Item) { Item.find(theId) } 
    title ||= item.title || "item#{item[:id]}"
    if item.kind_of?(Page)
      link_to title, :prefix => url_prefix, :controller => 'web', :action=>'item', :params=>{:path=>item.fullpath, :lang=>params[:lang]}
    else
      link_to title, :prefix => url_prefix, :controller => 'web', :action=>'item', :id=>item.id, :params=>{:lang=>params[:lang]}
    end
  rescue ActiveRecord::RecordNotFound
    "<span class='notFound'>item#{theId} not found</span>"
  end
    

  # Create IMG tag for zena additions to Textile
  def makeImage(img, options, format)
    if format != ""
      format = IMAGEBUILDER_FORMATS_BY_NUM[format.to_i] || 'pv'
    elsif img[0..0] == "0"
      format = 'pv'
    else
      format = 'std'
    end
    
    doc = secure(Document) { Document.find(img.to_i) }
    case options
    when ">"
      prefix = '<p class="float_right">'
      suffix = '</p>'
    when "<"
      prefix = '<p class="float_left">'
      suffix = '</p>'
    else
      prefix = suffix = ""
    end
    prefix + link_to( doc.img_tag(format), :prefix => url_prefix, :controller => 'web',
                            :action=>'item', :path=>doc.fullpath ) + suffix
  rescue ActiveRecord::RecordNotFound
    "<span class='notFound'>image#{img} not found</span>"
  end
  
  def makeDocs(ids)
    if ids == ""
      docs = @item.documents
    else
      docs = secure(Document) { Documents.find(:conditions=>["id IN (?)",ids])}
    end
    render_collection('document/docs', docs)
  end
  
  
  
	def date_box(obj, var, opts = {})
	  defaults = {  :id=>"datef#{object_id}", :button=>"dateb#{object_id}", :display=>"dated#{object_id}", :size=>15, :value=>ld(Time.now) }
	  opts = defaults.merge(opts)
	  date = eval "@#{obj} ? @#{obj}.#{var} : nil"
	  if date
	    opts[:value] = ld(date)
    end
	  s = text_field obj, var, :size=>opts[:size], :id=>opts[:id] , :value=>opts[:value]
		<<-EOL
#{s}
<img src="/calendar/iconCalendar.gif" id="#{opts[:button]}" style="cursor: pointer;" />
	<script type="text/javascript">
    Calendar.setup({
        inputField     :    "#{opts[:id]}",     // id of the input field
        button         :    "#{opts[:button]}",  // trigger for the calendar (button ID)
        align          :    "Br",
        singleClick    :    true
    });
</script>
		EOL
	end
	
	# Return the list of groups from the visitor for forms
	def groups
	  @groups ||= Group.find(:all, :select=>'id, name', :conditions=>"id IN (#{user_groups.join(',')})", :order=>"name ASC").collect {|p| [p.name, p.id]}
  end
  
  def site_tree(opt={})
    opt = {:form=>false, :skip=>nil, :base=>nil, :level=>0, :class=>Page}.merge(opt)
    skip  = opt[:skip]
    base  = opt[:base] || secure(Item) { Item.find(ZENA_ENV[:root_id]) }
    level = opt[:level]
    klass = opt[:class]
    tree = get_site_tree(skip,base,level,klass)
    return nil unless tree
    if opt[:form]
      tree.map {|p| ["  "*p[0] + p[1][:name], p[1][:id] ]}
    else
      tree
    end
  end
  def get_site_tree(skip=nil, base=nil, level=0, klass=Page)
    return nil if base[:id] == skip
    children = secure(klass) {klass.find(:all, :select=>['id, name, parent_id'], :conditions=>['parent_id=? AND type NOT IN (\'Document\',\'Image\')', base[:id]])}
    result = []
    if level
      result << [level, base]
      children.each do |child|
        next if child[:id] == skip
        res = get_site_tree(skip, child, level+1, klass)
        res.each {|r| result << r} if res
      end
      result
    else
      children.each do |child|
        next if child[:id] == skip
        item, grandchildren = get_site_tree(skip, child, nil, klass)
        result << [child, grandchildren]
      end
      [base, result]
    end
  end
  
end

=end