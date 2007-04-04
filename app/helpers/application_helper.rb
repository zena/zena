# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  include Zena::Acts::Secure
  
  def truc
    session.to_s
  end
  
  # helpers to include clean javascript
  def javascript( string )
    javascript_start +
    string +
    javascript_end
  end
  
  def javascript_start
    "<script type=\"text/javascript\" charset=\"utf-8\">\n// <![CDATA[\n"
  end
  
  def javascript_end
    "\n// ]]>\n</script>"
  end
  
  # Date selection tool
	def date_box(obj, var, opts = {})
	  rnd_id = rand(100000000000)
	  defaults = {  :id=>"datef#{rnd_id}", :button=>"dateb#{rnd_id}", :display=>"dated#{rnd_id}", :class=>var.to_s }
	  opts = defaults.merge(opts)
	  date = eval("@#{obj} ? @#{obj}.#{var} : nil") || Time.now.utc
	  value = tformat_date(date,'datetime')
    if opts[:size] == 0
      fld = hidden_field obj, var, :id=>opts[:id] , :value=>value, :class=>opts[:class]
    else
	    fld = text_field   obj, var, :id=>opts[:id] , :value=>value, :class=>opts[:class], :size=>opts[:size]
    end
		<<-EOL
<div class="date_box"><img src="/calendar/iconCalendar.gif" id="#{opts[:button]}"/>
#{fld}
	<script type="text/javascript">
    Calendar.setup({
        inputField     :    "#{opts[:id]}",      // id of the input field
        button         :    "#{opts[:button]}",  // trigger for the calendar (button ID)
        singleClick    :    true,
        showsTime      :    true
    });
</script></div>
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
  def login_link(opts={})
    unless visitor.is_anon?
      "<a href='/logout'>#{transb('logout')}</a>"
    else
      "<a href='/login'>#{transb('login')}</a>"
    end
  end
  
  # display the time with the format provided by the translation of 'long_time'
  def long_time(atime)
    tformat_date(atime, "long_time")
  end
  
  # display the time with the format provided by the translation of 'short_time'
  def short_time(atime)
    tformat_date(atime, "short_time")
  end
  
  # display the time with the format provided by the translation of 'full_date'
  def full_date(adate)
    tformat_date(adate, "full_date")
  end
  
  # display the time with the format provided by the translation of 'long_date'
  def long_date(adate)
    tformat_date(adate, "long_date")
  end
  
  # display the time with the format provided by the translation of 'short_date'
  def short_date(adate)
    tformat_date(adate, "short_date")
  end
  
  # format a date with the given format. Translate month and day names.
  def tformat_date(thedate, fmt)
    format_date(thedate, trans(fmt))
  end
  
  def format_date(thedate, format)
    return "" unless thedate
    adate = visitor.tz.adjust(thedate)
      # month name
    format = format.gsub("%b", trans(adate.strftime("%b")) )
    format.gsub!("%B", trans(adate.strftime("%B")) )
    # weekday name
    format.gsub!("%a", trans(adate.strftime("%a")) )
    format.gsub!("%A", trans(adate.strftime("%A")) )
    adate.strftime(format)
  end
  
  # Show visitor name if logged in
  def visitor_link(opts={})
    unless visitor.is_anon?
      link_to( visitor.fullname, user_home_url )
    else
      ""
    end
  end
  
  # Display flash[:notice] or flash[:error] if any. <%= flash <i>[:notice, :error, :both]</i> %>"
  def flash_messages(opts={})
    type = opts[:show] || 'both'
    "<div id='messages'>" +
    if (type == 'notice' || type == 'both') && @flash[:notice]
      "<div id='notice' class='flash' onclick='new Effect.Fade(\"notice\")'>#{@flash[:notice]}</div>"
    else
      ''
    end + 
    if (type == 'error'  || type == 'both') && @flash[:error ]
      "<div id='error' class='flash' onclick='new Effect.Fade(\"error\")'>#{@flash[:error]}</div>"
    else
      ''
    end +
    "</div>"
  end
  
  # This method renders the Textile text contained in an object as html. It also renders the zena additions :
  # === Zena additions
  # all these additions are replaced by the traduction of 'unknown link' or 'unknown image' if the user does
  # not have read access to the linked node.
  # * ["":34] creates a link to node 34 with node's title.
  # * ["title":34] creates a link to node 34 with the given title.
  # * ["":034] if the node id starts with '0', creates a popup link.
  # * [!14!] inline image 14 or link to document 14 with icon. (default format for images is 'std' defined in #ImageBuilder). Options are :
  # ** [!014!] if the id starts with '0', the image becomes a link to the full image.
  # ** [!<.14!] or [!<14!] inline image surrounded with <p class='img_left'></p>
  # ** [!>.14!] or [!>14!] inline image surrounded with <p class='img_right'></p>
  # ** [!=.14!] or [!=14!] inline image with <p class='img_center'></p>
  # ** [!14.pv!] inline image transformed to format 'pv' (class is also set to 'pv'). Formats are defined in #ImageBuilder.
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
    opt = {:images=>true, :pretty_code=>true}.merge(opt)
    img = opt[:images]
    if opt[:limit]
      opt[:limit] -= 1 unless opt[:limit] <= 0
      paragraphs = text.split(/\n\n|\r\n\r\n/)
      if paragraphs.size > (opt[:limit]+1) && opt[:limit] != -1
        text = paragraphs[0..opt[:limit]].join("\r\n\r\n") + "\r\n\r\np(more). " + trans("read more &#8230;")
      end
    end
    ZazenParser.new(text,:helper=>self).render(opt)
    #r = RedCloth.new(text) #, [:hard_breaks])
    #r.gsub!(  /(\A|[^\w])@(.*?)@(\Z|[^\w])/     ) { "#{$1}\\AT_START\\#{zazen_escape($2)}\\AT_END\\#{$3}" }
    #r.gsub!(  /<code>(.*?)<\/code>/m            ) { "\\CODE_START\\#{zazen_escape($1)}\\CODE_END\\" }
    #r.gsub!(  /\!\[([^\]]*)\]\!/                      ) { img ? make_gallery($1) : trans('[gallery]') }
    #r.gsub!(  /\!([^0-9]{0,2})\{([^\}]*)\}\!/                      ) { img ? list_nodes(:style=>$1, :ids=>$2)   : trans('[documents]')}
    #r.gsub!(  /\!([^0-9]{0,2})([0-9]+)(\.([^\/\!]+)|)(\/([^\!]*)|)\!(:([^\s]+)|)/ ) { img ? make_image(:style=>$1, :id=>$2, :size=>$4, :title=>$6, :link=>$8) : "[#{trans('image')}#{$6 ? (": " + zazen($6,:images=>false)) : ''}]"}
    #r.gsub!(  /"([^"]*)":([0-9]+)/                    ) { make_link(:title=>$1,:id=>$2)}
    #r = r.to_html
    #r.gsub!(  /(\\CODE_START\\)(.*?)(\\CODE_END\\)/m    ) { "<div class='box'>#{zazen_unescape($2)}</div>" }
    #r.gsub!(  /(\\AT_START\\)(.*?)(\\AT_END\\)/         ) { "#{zazen_unescape($2)}" }
    #r.gsub!(  /\?(\w[^\?]+?\w)\?/               ) { make_wiki_link($1) }
    #r
  end
  
  # TODO: test
  def zazen_diff(text1, text2, opt={})
    HTMLDiff::diff(zazen(text1), zazen(text2))
  end
  
  # Creates a link to the node referenced by id
  def make_link(opts)
    node = secure(Node) { Node.find_by_zip(opts[:id]) }
    title = (opts[:title] && opts[:title] != '') ? opts[:title] : node.v_title
    if opts[:id][0..0] == '0'
      link_to title, node_url(node), :popup=>true
    else
      link_to title, node_url(node)
    end
  rescue ActiveRecord::RecordNotFound
    "<span class='unknownLink'>#{trans('unknown link')}</span>"
  end
  
  # TODO: test
  def make_wiki_link(opts)
    if opts[:url]
      if opts[:url][0..3] == 'http'
        "<a href='#{opts[:url]}' class='wiki'>#{opts[:title]}</a>"
      else
        "<a href='http://#{lang}.wikipedia.org/wiki/#{opts[:url]}' class='wiki'>#{opts[:title]}</a>"
      end
    else
      "<a href='http://#{lang}.wikipedia.org/wiki/Special:Search?search=#{CGI::escape(opts[:title])}' class='wiki'>#{opts[:title]}</a>"
    end
  end
  # Create an img tag for the given image. See ApplicationHelper#zazen for details.
  def make_image(opts)
    id, style, link, size, title = opts[:id], opts[:style], opts[:link], opts[:size], opts[:title]
    img = secure(Document) { Document.find_by_zip(id) }
    if !opts[:images].nil? && !opts[:images]
      return "[#{trans('image')}: #{img.v_title}]"
    end
    title = img.v_summary if title == ""
    size = IMAGEBUILDER_FORMAT[size] ? size : nil
    if !size && img.kind_of?(Image)
      size = 'std'
    end
    image = img.img_tag(size)
    
    unless link
      if id[0..0] == "0" || !img.kind_of?(Image)
        # if the id starts with '0' or it is not an Image, link to data
        link = url_for(data_url(img))
      end
    end
    
    style ||= ''
    case style.sub('.', '')
    when ">"
      prefix = "<div class='img_right'>"
      suffix = "</div>"
    when "<"
      prefix = "<div class='img_left'>"
      suffix = "</div>"
    when "="
      prefix = "<div class='img_center'>"
      suffix = "</div>"
    else
      prefix = suffix = ""
    end
    
    if title
      prefix = "#{prefix}<div class='img_with_title'>"
      suffix = "<div class='img_title'>#{Zazen::Parser.new(title,self).render(:images=>false)}</div></div>#{suffix}"
    end
    
    if link.nil?
      prefix + image + suffix
    elsif link =~ /^\d+$/
      prefix + make_link(:id=>link,:title=>image) + suffix
    else
      link = "http://#{link}" unless link =~ %r{(^/|.+://.+)}
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
      ids = ids.split(',').map{|i| i.to_i} # sql injection security
      images = secure(Document) { Document.find_by_zip(:all, :conditions=>"zip IN (#{ids.join(',')})") }
      # order like ids :
      images.sort! {|a,b| ids.index(a[:id].to_i) <=> ids.index(b[:id].to_i) }
    end
    
    render_to_string( :partial=>'main/gallery', :locals=>{:gallery=>images} )
  end

  def list_nodes(opt={})
    ids = opt[:ids]
    style = opt[:style] || ''
    case style.sub('.', '')
    when ">"
      prefix = "<div class='img_right'>"
      suffix = "</div>"
    when "<"
      prefix = "<div class='img_left'>"
      suffix = "</div>"
    when "="
      prefix = "<div class='img_center'>"
      suffix = "</div>"
    else
      prefix = suffix = ""
    end
    if ids == ""
      docs = @node.documents
    elsif ids == "d"
      docs = @node.documents_only
    elsif ids == "i"
      docs = @node.images
    else
      ids = ids.split(',').map{|i| i.to_i}.join(',') # sql injection security
      docs = secure(Document) { Document.find(:all, :order=>'name ASC', :conditions=>"zip IN (#{ids})") }
    end
    prefix + render_to_string( :partial=>'main/list_nodes', :locals=>{:docs=>docs}) + suffix
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
  
  # default date used to filter events in templates
  def main_date
    @date ||= Time.now
  end
  
  # Creates a hierachical menu. When :collection is specified, use this as the menu's root elements. Otherwise, uses
  # the root element as the menu's start.
  def show_menu(opts={})
    collection = opts[:collection] ? opts[:collection].map{|r| r[:id]}.join(',') : ""
    Cache.with(visitor.id, visitor.group_ids, Page.kpath, 'show_menu', collection) do
      menus  = opts[:collection] || secure(Node) { Node.find(visitor.site[:root_id]) }.pages
      res = []
      res << "<ul class='menu'>"
      res << render_to_string(:partial=>'main/menu', :collection=>menus)
      res << "</ul>"
      res.join("\n")
    end
  end
  
  # Display the list of comments for the current node
  def show_comments(opts={})
    node = opts[:node] || @node
    render_to_string(:partial=>'comment/list', :locals=>{:node=>node})
  end
  
  def calendar(options={})
    source = options[:from  ] || (@project ||= (@node ? @node.project : nil))
    date   = options[:date  ] || Date.today
    method = options[:find  ] || :notes
    size   = options[:size  ] || :tiny
    using  = options[:using ] || :event_at
    day_names, on_day = calendar_get_options(size, source, method)
    return "" unless on_day && source
    Cache.with(visitor.id, visitor.group_ids, 'NN', size, method, source.id, date.ajd, lang) do
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
  
  # Show a little [xx] next to the title if the desired language could not be found.
  def check_lang(obj)
    obj.v_lang != lang ? " <span class='wrong_lang'>[#{obj.v_lang}]</span> " : ""
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
      opts[:link] = (obj[:id] != @node[:id])
    end
    unless opts.include?(:project)
      opts[:project] = (obj[:project_id] != @node[:project_id] && obj[:id] != @node[:id]) 
    end
    if opts[:project]
      title = "#{obj.project.name} / #{obj.v_title}"
    else
      title = obj.version.title
    end
    if opts[:link]
      title = link_to(title, node_url(obj))
    end
    "<span id='v_title#{obj.v_id}'>#{title + check_lang(obj)}</span>"
  end
  
  # TODO: test
  def show(obj, sym, opt={})
    return show_title(obj, opt) if sym == :v_title
    if opt[:as]
      key = "#{opt[:as]}#{obj.v_id}"
      preview_for = opt[:as]
      opt.delete(:as)
    else
      key = "#{sym}#{obj.v_id}"
    end
    if opt[:text]
      text = opt[:text]
      opt.delete(:text)
    else
      text = obj.send(sym)
      if (text.nil? || text == '') && sym == :v_summary
        text = obj.v_text
        opt[:images] = false
      else
        opt.delete(:limit)
      end
    end
    if [:v_text, :v_summary].include?(sym)
      if obj.kind_of?(TextDocument) && sym == :v_text
        lang = obj.content_lang
        lang = lang ? " lang='#{lang}'" : ""
        text = "<code#{lang} class='full'>#{text}</code>"
      end
      text  = zazen(text, opt)
      klass = " class='zazen'"
    else
      klass = ""
    end
    if preview_for
      render_to_string :partial=>'node/show_attr', :locals=>{:id=>obj[:id], :text=>text, :preview_for=>preview_for, :key=>key, :klass=>klass,
                                                           :key_on=>"#{key}#{Time.now.to_i}_on", :key_off=>"#{key}#{Time.now.to_i}_off"}
    else
      "<div id='#{key}'#{klass}>#{text}</div>"
    end
  end
  
  # Display a selection 'box' for a given role (provided by the sym argument). Depending on the role type
  # this helper may render a checkbox list, a select menu or an input field for an id. Available choices
  # may be reduced by providing a list as :in argument : link_box('node', :calendars, :in=>[1,11]).
  def link_box(obj, sym, opt={})
    node = instance_variable_get("@#{obj}".to_sym)
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
	  @form_groups ||= Group.find(:all, :select=>'id, name', :conditions=>"id IN (#{visitor.group_ids.join(',')})", :order=>"name ASC").collect {|p| [p.name, p.id]}
  end
  
  #TODO: test
  # Return the list of possible templates
  def form_skins
    return @form_skins if @form_skins
    @form_skins = secure(Skin) { Skin.find(:all, :order=>'name ASC') }.map {|r| r[:name]}
    Dir.foreach(File.join(RAILS_ROOT, 'app', 'views', 'templates', 'fixed')) do |file|
      next unless file =~ /^([a-zA-Z0-9_]+)$/
      @form_skins << $1 unless @form_skins.include?($1)
    end
    @form_skins
  end
  
  #TODO: test
  def site_tree(obj=nil)
    skip  = obj ? obj[:id] : nil
    base  = secure(Node) { Node.find(visitor.site[:root_id]) }
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
  
  
  # Used by node_actions
  def form_action(action, version_id=nil, link_text=nil)
    version_id ||= @node.v_id
    if action == 'edit'
      "<a href='#' title='#{transb('btn_title_edit')}' onclick=\"editor=window.open('" + 
      url_for(:controller=>'version', :id=>version_id, :action=>'edit', :rnd=>rnd) + 
      "', '_blank', 'location=0,width=300,height=400,resizable=1');return false;\">" + (link_text || transb('btn_edit')) + "</a>"
    elsif action == 'drive'
      "<a href='#' title='#{transb('btn_title_drive')}' onclick=\"editor=window.open('" + 
      url_for(:controller=>'node', :version_id=>version_id, :action=>'drive', :rnd=>rnd) + 
      "', '_blank', 'location=0,width=300,height=400,resizable=1');return false;\">" + (link_text || transb('btn_drive')) + "</a>"
    else
      tlink_to( (link_text || "btn_#{action}"), {:controller=>'version', :action => action , :id => version_id}, :title=>transb("btn_title_#{action}"), :post=>true ) + "\n"
    end
  end
  
  # Buttons are :edit, :add, :propose, :publish, :refuse, or :drive. :all = (:edit, :propose, :publish, :refuse, :drive)
  def node_actions(opts={})
    action = (opts[:actions] || :all).to_sym
    res = []
    if opts[:node]
      version_id = opts[:node].v_id
      node = opts[:node]
    else
      version_id = nil
      node = @node
    end
    if (action == :edit or action == :all) && node.can_edit?
      res << form_action('edit',version_id, opts[:text])
    end
    if (action == :propose or action == :all) && node.can_propose?
      res << form_action('propose',version_id, opts[:text])
    end
    if (action == :publish or action == :all) && node.can_publish?
      res << form_action('publish',version_id, opts[:text])
    end
    if (action == :refuse or action == :all) && node.can_refuse?
      res << form_action('refuse',version_id, opts[:text])
    end
    if (action == :drive or action == :all) && node.can_drive?
      res << form_action('drive',version_id, opts[:text])
    end
    if res != []
      "<span class='actions'>#{res.join(" ")}</span>"
    else
      ""
    end
  end
  
  # TODO: test
  def version_form_action(action,version_id)
    if action == 'view'
      tlink_to_function('btn_view', "opener.Zena.version_preview(#{version_id});")
    else
      tlink_to_remote( "btn_#{action}", :url=>{:controller=>'version', :action => action , :id => version_id, :drive=>true}, :title=>transb("btn_title_#{action}"), :post=>true ) + "\n"
    end
  end
  # TODO: test
  # show actions on versions
  def version_actions(version, opt={})
    opt = {:action=>:all}.merge(opt)
    return "" unless version.kind_of?(Version)
    actions = []
    if opt[:action] == :view
      if (version.status != Zena::Status[:del] && version.status != Zena::Status[:red]) ||  (version[:user_id] == visitor.id )
        actions << version_form_action('view', version[:id])
      end
    elsif opt[:action] == :all
      case version.status
      when Zena::Status[:pub]
        actions << version_form_action('unpublish',version[:id]) if @node.can_unpublish?(version)
      when Zena::Status[:prop]
        actions << version_form_action('publish',version[:id])
        actions << version_form_action('refuse',version[:id])
      when Zena::Status[:prop_with]
        actions << version_form_action('publish',version[:id])
        actions << version_form_action('refuse',version[:id])
      when Zena::Status[:red]
        if version.user[:id] == visitor.id
          actions << version_form_action('publish',version[:id])
          actions << version_form_action('propose',version[:id])
          actions << version_form_action('remove',version[:id])
        end
      when Zena::Status[:rep]
        actions << version_form_action('edit',version[:id]) if @node.can_edit_lang?(version.lang)
        actions << version_form_action('publish',version[:id])
        actions << version_form_action('propose',version[:id])
      when Zena::Status[:rem]
        actions << version_form_action('edit',version[:id]) if @node.can_edit_lang?(version.lang)
        actions << version_form_action('publish',version[:id])
        actions << version_form_action('propose',version[:id])
      when Zena::Status[:del]
        if (version[:user_id] == visitor[:id])
          actions << version_form_action('edit',version[:id]) if @node.can_edit_lang?(version.lang)
        end
      end
    end
    actions.join(" ")
  end
  
  # TODO: test
  def discussion_actions(discussion, opt={})
    opt = {:action=>:all}.merge(opt)
    return '' unless @node.can_drive?
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
    return '' if RAILS_ENV == 'production'
    str = <<ENDTXT
    <div id='css_edit'>
      <div id='css' onclick='cssUpdate()'></div>
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
        t=setTimeout("timedCount()",2000)
      }

      function stopCount()
      {
        clearTimeout(t)
      }

      </script>
      <form>
        <input type="button" value="Start CSS" onclick="timedCount()">
        <input type="button" value="Stop  CSS" onclick="stopCount()">
        <span id='css_counter'></span> <input type='text' id='css_file' name='css_file' value='#{css_file}'/>
      </form>
    </div>
    
ENDTXT
  end
  
  # Traductions as a list of links
  def traductions(opts={})
    obj = opts[:node] || @node
    trad_list = []
    base_url = node_url(obj)
    (obj.traductions || []).map do |ed|
      trad_list << "<span>" + link_to( trans(ed[:lang]), base_url.merge(:lang=>ed[:lang])) + "</span>"
    end
    trad_list
  end
  
  def change_lang(new_lang)
    if visitor.is_anon?
      {:overwrite_params => { :prefix => new_lang }}
    else
      {:overwrite_params => { :lang => new_lang }}
    end
  end
  
  # show author information
  # size can be either :small or :large, options are
  # :node=>object
  def show_author(opts={})
    obj  = opts[:node] || @node
      res = []
      if  obj.author.id == obj.v_author.id
        res << trans("posted by") + " <b>" + obj.author.fullname + "</b>"
      else
        res << trans("original by") + " <b>" + obj.author.fullname + "</b>"
        res << trans("new post by") + " <b>" + obj.v_author.fullname + "</b>"
      end
      res << trans("on") + " " + short_date(obj.v_updated_at) + "."
      res << trans("Traductions") + " : <span id='trad'>" + traductions.join(", ") + "</span>"
      res.join("\n")
  end
  
  # show current path with links to ancestors
  def show_path(opts={})
    node = opts[:node] || @node
    nav = []
    node.ancestors.each do |obj|
      nav << link_to(obj.name, node_url(obj))
    end
    
    nav << "<a href='#{url_for(node_url(node))}' class='current'>#{node.name}</a>"
    res = "<ul class='path'>"
    "#{res}<li>#{nav.join(" / </li><li>")}</li></ul>"
  end
  
  # TODO: test
  def node_link(opts={})
    options = {:node=>@node, :href=>'self', :url=>{}}.merge(opts)
    node = options[:node]
    if options[:href]
      node = node.relation(options[:href]) || node
    end  
    text = options[:text] || node.version.title
    if opts[:dash]
      "<a href='##{opts[:dash]}'>#{text}</a>"
    else
      url = node_url(node)
      link_to(text,url.merge(options[:url]))
    end
  end
  
  # shows links for site features
  def show_link(link, opt={})
    case link
    when :admin_links
      [show_link(:home), show_link(:preferences), show_link(:comments), show_link(:users), show_link(:groups), show_link(:translation)].reject {|l| l==''}
    when :home
      return '' if visitor.is_anon?
      tlink_to_with_state('my home', :controller=>'user', :action=>'home')
    when :preferences
      return '' if visitor.is_anon?
      tlink_to_with_state('preferences', :controller=>'preferences', :action=>'list')
    when :translation
      return '' unless visitor.group_ids.include?(visitor.site[:trans_group_id])
      tlink_to_with_state('translate interface', :controller=>'trans', :action=>'list')
    when :comments
      return '' unless visitor.is_admin?
      tlink_to_with_state('manage comments', :controller=>'comment', :action=>'list')
    when :users
      return '' unless visitor.is_admin?
      tlink_to_with_state('manage users', :controller=>'user', :action=>'list')
    when :groups
      return '' unless visitor.is_admin?
      tlink_to_with_state('manage groups', :controller=>'group', :action=>'list')
    when :site_tree
      tlink_to_with_state('site tree', :controller=>'main', :action=>'site_tree', :id=>@node)
    when :print
      if @node
        tlink_to('print', :controller=>'main', :action=>'print', :id=>@node)
      else
        ''
      end
    else
      ''
    end
  end
  
  # Calendar seizure setup
  def uses_calendar(opt={})
    if ZENA_CALENDAR_LANGS.include?(lang)
      l = lang
    else
      l = visitor.site[:default_lang]
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
  
  # show language selector
  def lang_links(opts={})
    if visitor.site[:monolingual]
      ""
    else
      res = []
      visitor.site.lang_list.sort.each do |l|
        if l == lang
          res << "<b>#{l}</b>"
        else
          if visitor.is_anon?
            res << link_to(l, request.parameters.merge(:prefix=>l))
          else
            res << link_to(l, request.parameters.merge(:lang=>l))
          end
        end
      end
      res.join(' | ')
    end
  end
  
  def lang_ajax_link
    if visitor.site[:monolingual]
      "<div id='lang' class='empty'></div>"
    else
      res = "<div id='lang'><span>" + link_to_remote( lang, :update=>'lang', :url=>{:controller => 'trans', :action=>'lang_menu'})
      if session[:translate]
        res << show_link(:translation, :menu=>true)
      end
      res << '</span></div>'
      res
    end
  end
  
  # TODO: test
  def search_box(opts={})    
    render_to_string(:partial=>'search/form')
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
            res << "<div>" + link_to_remote(e.v_title.limit(14), 
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
  
  # Display an input field to select an id. The user can enter an id or a name in the field and the
  # node's path is shown next to the input field. If the :class option is specified and the elements
  # in this class are not too many, a select menu is shown instead (nodes in the menu are found using secure_write scope).
  # 'Sym' is the field to select the id for (parent_id, ...).
  def select_id(obj, sym, opt={})
    if ['Project', 'Tag', 'Contact'].include?(opt[:class].to_s)
      klass = opt[:class].kind_of?(Class) ? opt[:class] : Module::const_get(opt[:class].to_sym)
      return select(obj,sym,  secure_write(klass) { klass.find(:all, :select=>'id,name', :order=>'name ASC') }.map{|r| [r[:name], r[:id]]}, { :include_blank => opt[:include_blank] })
    end
    node = instance_variable_get("@#{obj}".to_sym)
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
    # we use both 'onChange' and 'onKeyup' for old javascript compatibility
    update = "new Ajax.Updater('#{name_ref}', '/z/node/attribute/' + this.value + '?attr=#{attribute}', {asynchronous:true, evalScripts:true});"
    "<div class='select_id'><input type='text' size='8' id='#{obj}_#{sym}' name='#{obj}[#{sym}]' value='#{id}' onChange=\"#{update}\" onKeyup=\"#{update}\"/>"+
    "<span class='select_id_name' id='#{name_ref}'>#{current}</span></div>"
  end
end
=begin

# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  include Zena::Acts::SecureScope
  include Zena::Acts::Secure::InstanceMethods
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
