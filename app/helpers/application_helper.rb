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
    Time.now.to_i
  end

  # "Translate" static text into the current lang
  def trans(keyword, edit=true)
    key = TransKey.translate(keyword)
    if session[:translate] && edit # set wether untranslated text will be editable or not
      "<div id='trans_#{key[:id]}' class='trans'>" + 
      link_to_remote(key.into(lang), 
          :update=>"trans_#{key[:id]}", 
          :url=>"/z/trans/edit/#{key[:id]}",
          :complete=>'$("trans_value").focus();$("trans_value").select()') +
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
  def format_date(adate, fmt)
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
  def parse_date(datestr, fmt=trans("long_date"))
    elements = datestr.split(/(\.|\-|\/|\s)+/)
    format = fmt.split(/(\.|\-|\/|\s)+/)
    if elements
      hash = {}
      elements.each_index do |i|
        hash[format[i]] = elements[i]
      end
      hash['%Y'] ||= hash['%y'] ? (hash['%y'].to_i + 2000) : Time.now.year
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
  
  # Display flash[:notice] or flash[:error] if any. <%= flash <i>[:notice, :error, :both]</i> %>"
  def flash_messages(type=:both)
    if (type == :notice || type == :both) && @flash[:notice]
      "<div id='notice' onClick='new Effect.Fade(\"notice\")'>#{@flash[:notice]}</div>"
    else
      ''
    end + 
    if (type == :error  || type == :both) && @flash[:error ]
      "<div id='error' onClick='new Effect.Fade(\"error\")'>#{@flash[:error]}</div>"
    else
      ''
    end
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
  # not have read access to the linked item.
  # * ["":34] creates a link to item 34 with item's title.
  # * ["title":34] creates a link to item 34 with the given title.
  # * ["":034] if the item id starts with '0', creates a popup link.
  # * [!14!] inline image 14. (default format is 'std' defined in #ImageBuilder). Options are :
  # ** [!014!] inline image with 'pv' format
  # ** [!<.14!] or [!<14!] inline image surrounded with <p class='img_left'></p>
  # ** [!>.14!] or [!>14!] inline image surrounded with <p class='img_right'></p>
  # ** [!=.14!] or [!=14!] inline image with <p class='img_center'></p>
  # ** [!14.pv!] inline image transformed to format 'pv'. Formats are defined in #ImageBuilder.
  # ** all the options above can be used together as in [!>.14.med!] : inline image on the right, size 'med'.
  # ** [![2,3,5]!] gallery : inline preview with javascript inline viewer
  # ** [![]!] gallery with all images contained in the current item
  # * [!{7,9}!] documents listing for documents 7 and 9
  # * [!{}!] list all documents (with images) for the current item
  # * [!{d}!] list all documents (without images) for the current item
  # * [!{i}!] list all images for the current item
  # * [!14!:37] you can use an image as the source for a link
  # * [!14!:www.example.com] use an image for an outgoing link
  def zazen(text)
    r = RedCloth.new(text) #, [:hard_breaks])
    r.gsub!(  /"([^"]*)":([0-9]+)/                    ) {|x| make_link(:title=>$1,:id=>$2)}
    r.gsub!(  /\!\[([^\]]*)\]\!/                      ) {|x| make_gallery($1)}
    r.gsub!(  /\!\{([^\}]*)\}\!/                      ) {|x| list_items($1)}
    r.gsub!(  /\!([^0-9]{0,2})([0-9]+)(\.([^\!]+)|)\!(:([^\s]+)|)/ ) {|x| make_image(:style=>$1, :id=>$2, :size=>$4, :link=>$6)}
    r
    r.to_html
  end

  # Creates a link to the item referenced by id
  def make_link(opts)
    item = secure(Item) { Item.find(opts[:id]) }
    title = (opts[:title] && opts[:title] != '') ? opts[:title] : item.title
    if opts[:id][0..0] == '0'
      link_to title, {:prefix => prefix, :controller => 'main', :action=>'show', :path=>item.fullpath}, :popup=>true
    else
      link_to title, :prefix => prefix, :controller => 'main', :action=>'show', :path=>item.fullpath
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
      image = img.img_tag(size || 'std')
    else
      image = img.img_tag(size)
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
      images = @item.images
    else
      ids = ids.split(',').map{|i| i.to_i}.join(',') # sql injection security
      images = secure(Document) { Document.find(:all, :conditions=>"id IN (#{ids})") }
    end
    render_to_string( :partial=>'main/gallery', :locals=>{:gallery=>images} )
  end

  def list_items(ids='')
    if ids == ""
      docs = @item.documents
    elsif ids == "d"
      docs = @item.documents_only
    elsif ids == "i"
      docs = @item.images
    else
      ids = ids.split(',').map{|i| i.to_i}.join(',') # sql injection security
      docs = secure(Document) { Document.find(:all, :order=>'name ASC', :conditions=>"id IN (#{ids})") }
    end
    render_to_string( :partial=>'main/list_items', :locals=>{:docs=>docs})
  end
  
  def data_url(obj)
    if obj.kind_of?(Document)
      {:controller=>'document', :action=>'data', :version_id=>obj.v_id, :filename=>obj.name, :ext=>obj.ext}
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
  
  private
  
  # This lets helpers render partials
  def render_to_string(*args)
    @controller.send(:render_to_string, *args)
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