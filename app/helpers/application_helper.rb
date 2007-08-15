# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  include Zena::Acts::Secure
  
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
	  defaults = {  :id=>"datef#{rnd_id}", :button=>"dateb#{rnd_id}", :display=>"dated#{rnd_id}" }
	  opts = defaults.merge(opts)
	  date = eval("@#{obj} ? @#{obj}.#{var} : nil") || Time.now.utc
	  value = tformat_date(date,'datetime')
    if opts[:size]
      fld = "<input id='#{opts[:id]}' name='#{obj}[#{var}]' type='text' size='#{opts[:size]}' value='#{value}' />"
    else
      fld = "<input id='#{opts[:id]}' name='#{obj}[#{var}]' type='text' value='#{value}' />"
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
    
  # Add class='on' if the link points to the current page
  def link_to_with_state(*args)
    title, url, options = *args
    options ||= {}
    if request.path == url
      options[:class] = 'on'
    end
    link_to(title, url, options)
  end
  
  # creates a pseudo random string to avoid browser side ajax caching
  def rnd
    Time.now.to_i
  end
  
  # We need to create the accessor for zafu calls to the helper to work when compiling templates. Do not ask me why this works...
  def session
    @session || {}
  end
  
  # We need to create the accessor for zafu calls to the helper to work when compiling templates. Do not ask me why this works...
  def flash
    @flash || {}
  end
  
  # "Translate" static text into the current lang
  # def _(keyword, opt={})
  #   opt = {:edit=>true}.merge(opt)
  #   if opt[:translate] || (session[:translate] && opt[:edit])
  #     key = TransPhrase.translate(keyword)
  #     "<div id='phrase#{key[:id]}' class='trans'>" + 
  #     link_to_remote(key.into(lang),
  #         :update=>"phrase#{key[:id]}", 
  #         :url => {:controller=>'_(', :action=>')edit', :id=>key[:id]},
  #         :complete=>'$("trans_value").focus();$("trans_value").select()') +
  #     "</div>"
  #   else
  #     TransPhrase[keyword][lang]
  #   end
  # end
  
  # Shows 'login' or 'logout' button.
  def login_link(opts={})
    if visitor.is_anon?
      if visitor.site[:http_auth] || true
        if params[:prefix]
          link_to _('login'), :overwrite_params => { :prefix => AUTHENTICATED_PREFIX }
        else
          "<a href='/login'>#{_('login')}</a>"
        end
      else
        "<a href='/login'>#{_('login')}</a>"
      end
    else  
      "<a href='/logout'>#{_('logout')}</a>"
    end
  end
  
  # display the time with the format provided by the translation of 'long_time'
  def long_time(atime)
    format_date(atime, _("long_time"))
  end
  
  # display the time with the format provided by the translation of 'short_time'
  def short_time(atime)
    format_date(atime, _("short_time"))
  end
  
  # display the time with the format provided by the translation of 'full_date'
  def full_date(adate)
    format_date(adate, _("full_date"))
  end
  
  # display the time with the format provided by the translation of 'long_date'
  def long_date(adate)
    format_date(adate, _("long_date"))
  end
  
  # display the time with the format provided by the translation of 'short_date'
  def short_date(adate)
    format_date(adate, _("short_date"))
  end
  
  # format a date with the given format. Translate month and day names.
  def tformat_date(thedate, fmt)
    format_date(thedate, _(fmt))
  end
  
  def format_date(thedate, format)
    return "" unless thedate
    adate = visitor.tz.adjust(thedate)
      # month name
    format = format.gsub("%b", _(adate.strftime("%b")) )
    format.gsub!("%B", _(adate.strftime("%B")) )
    # weekday name
    format.gsub!("%a", _(adate.strftime("%a")) )
    format.gsub!("%A", _(adate.strftime("%A")) )
    adate.strftime(format)
  end
  
  # Show visitor name if logged in
  def visitor_link(opts={})
    unless visitor.is_anon?
      link_to( visitor.fullname, user_path(visitor) )
    else
      ""
    end
  end
  
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
    return '' unless text
    opt = {:images=>true, :pretty_code=>true}.merge(opt)
    img = opt[:images]
    if opt[:limit]
      opt[:limit] -= 1 unless opt[:limit] <= 0
      paragraphs = text.split(/\n\n|\r\n\r\n/)
      if paragraphs.size > (opt[:limit]+1) && opt[:limit] != -1
        text = paragraphs[0..opt[:limit]].join("\r\n\r\n") + " &#8230;"
      end
    end
    ZazenParser.new(text,:helper=>self, :node=>(opt[:node] || @node)).render(opt)
  end
  
  # TODO: test
  def zazen_diff(text1, text2, opt={})
    HTMLDiff::diff(zazen(text1), zazen(text2))
  end
  
  # Creates a link to the node referenced by id
  def make_link(opts)
    link_opts = {}
    if sharp = opts[:sharp]
      if sharp =~ /\[(.+)\/(.*)\]/
        sharp_in, sharp = $1, $2
        sharp = "[#{sharp}]" if sharp != ''
        link_opts[:sharp_in] = sharp_in
      end
      link_opts[:sharp]    = sharp
    end
    if opts[:id] =~ /(\d+)(_\w+|)(\.\w+|)/
      opts[:id]     = $1
      link_opts[:mode]   = ($2 != '') ? $2[1..-1] : nil
      link_opts[:format] = ($3 != '') ? $3[1..-1] : nil
    end
    node = secure(Node) { Node.find_by_zip(opts[:id]) }
    title = (opts[:title] && opts[:title] != '') ? opts[:title] : node.v_title
    
    link_opts[:format] = node.c_ext if link_opts[:format] == 'data'
    if opts[:id][0..0] == '0'
      link_to title, zen_path(node, link_opts), :popup=>true
    else
      link_to title, zen_path(node, link_opts)
    end
  rescue ActiveRecord::RecordNotFound
    "<span class='unknownLink'>#{_('unknown link')}</span>"
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
      return "[#{_('image')}: #{img.v_title}]"
    end
    title = img.v_summary if title == ""
    size = IMAGEBUILDER_FORMAT[size] ? size : nil
    if !size && img.kind_of?(Image)
      size = 'std'
    end
    
    image = img_tag(img, :mode=>size)
    
    unless link
      if id[0..0] == "0" || !img.kind_of?(Image)
        # if the id starts with '0' or it is not an Image, link to data
        link = zen_path(img, :format => img.c_ext)
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
      suffix = "<div class='img_title'>#{ZazenParser.new(title,:helper=>self).render(:images=>false)}</div></div>#{suffix}"
    end
    
    if link.nil?
      prefix + image + suffix
    elsif link =~ /^\d+/
      prefix + make_link(:id=>link,:title=>image) + suffix
    else
      link = "http://#{link}" unless link =~ %r{(^/|.+://.+)}
      prefix + "<a href='#{link}'>" + image + "</a>" + suffix
    end
  rescue ActiveRecord::RecordNotFound
    "<span class='unknownLink'>#{_('unknown document')}</span>"
  end
  
  # Create a gallery from a list of images. See ApplicationHelper#zazen for details.
  def make_gallery(ids="", opts={})
    if ids == ""
      images = (opts[:node] || @node).images
    else
      ids = ids.split(',').map{|i| i.to_i} # sql injection security
      images = secure(Document) { Document.find(:all, :conditions=>"zip IN (#{ids.join(',')})") }
      # order like ids :
      images.sort! {|a,b| ids.index(a[:zip].to_i) <=> ids.index(b[:zip].to_i) }
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
    return '' unless docs
    prefix + render_to_string( :partial=>'main/list_nodes', :locals=>{:docs=>docs}) + suffix
  end
  
  # Display an image tag for the given node. If no mode is provided, 'full' is used. Options are ':mode', ':id', ':alt' and ':class'. If no class option is passed,
  # the format is used as the image class. Example :
  #   img_tag(@node, :mode=>'pv')  => <img src='/sites/test.host/data/jpg/20/bird_pv.jpg' height='80' width='80' alt='bird' class='pv'/>
  def img_tag(obj, options={})
    Node.logger.info obj.inspect
    opts    = options.dup
    
    mode    = opts.delete(:mode)
    klass   = opts.delete(:class)
    alt     = opts.delete(:alt)
    img_id  = opts.delete(:id)
    
    if obj.kind_of?(Document)
      content = obj.v_content
      ext     = content.ext
    end
    
    src = width = height = img_class = nil
    if obj.kind_of?(Image)
      alt  ||= obj.v_title.gsub("'", '&apos;')
      mode   = content.verify_format(mode) || 'std'
      
      src    = data_path(obj, opts.merge(:mode => (mode == 'full' ? nil : mode)))
      
      img_class = klass || mode
      if mode == 'full'
        # full size (format = nil)
        width = content.width
        height= content.height
      elsif content[:width] && content[:height]
        # compute image size
        width = content.width(mode)
        height= content.height(mode)
      end
    else
      mode    = IMAGEBUILDER_FORMAT[mode] ? mode : nil
      
      if obj.kind_of?(Document)
        icon  = ext
        alt ||= _('%{ext} document') % {:ext => ext}
      else
        icon = obj.class.to_s.downcase
        alt ||= _('%{type} node') % {:type => icon}
      end
      
      img_class = klass || 'doc'
      unless File.exist?("#{RAILS_ROOT}/public/images/ext/#{icon}.png")
        icon = 'other'
      end
      
      unless mode
        # img_tag from extension
        width  = 32
        height = 32
        src    = "/images/ext/#{icon}.png"
      else
        img = ImageBuilder.new(:path=>"#{RAILS_ROOT}/public/images/ext/#{icon}.png", :width=>32, :height=>32)
        img.transform!(mode)
        width  = img.width
        height = img.height
        
        filename = "#{icon}_#{mode}.png"
        path     = "#{RAILS_ROOT}/public/images/ext/"
        unless File.exist?(File.join(path,filename))
          # make new image with the mode
          unless File.exist?(path)
            FileUtils::mkpath(path)
          end
          if img.dummy?
            File.cp("#{RAILS_ROOT}/public/images/ext/#{icon}.png", "#{RAILS_ROOT}/public/images/ext/#{filename}")
          else
            File.open(File.join(path, filename), "wb") { |f| f.syswrite(img.read) }
          end
        end
        
        src    = "/images/ext/#{filename}"
      end
    end
    res = "<img src='#{src}'"
    [[:width, width], [:height, height], [:alt, alt], [:id, img_id], [:class, img_class]].each do |k,v|
      next unless v
      res << " #{k}='#{v}'"
    end
    res << "/>"
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
    @date ||= Date.today
  end
  
  # Display the list of comments for the current node
  def show_comments(opts={})
    node = opts[:node] || @node
    render_to_string(:partial=>'comments/list', :locals=>{:node=>node})
  end
  
  def calendar(opts={})
    source    = opts[:node  ] || (@project ||= (@node ? @node.project : nil))
    date      = opts[:date  ] || Date.today
    
    if opts[:template_url]
      opts = eval_parameters_from_template_url(opts[:template_url])
    end
    
    relations = opts[:relations] || 'notes'
    size      = opts[:size  ] || 'tiny'
    using     = opts[:using ] || 'event_at'
    day_names, on_day = calendar_get_options(size, source, opts[:template_url])
    return "" unless on_day && source
    
    Cache.with(visitor.id, visitor.group_ids, 'NN', size, relations, source.id, date.ajd, lang) do
      # find start and end date
      week_start_day = _('week_start_day').to_i
      start_date  = Date.civil(date.year, date.mon, 1)
      start_date -= (start_date.wday + 7 - week_start_day) % 7
      end_date    = Date.civil(date.year, date.mon, -1)
      end_date   += (6 + week_start_day - end_date.wday) % 7
      
      # get list of notes in this scope
      notes = source.find(:all, :relations => relations, :conditions=>["#{using} >= ? AND #{using} <= ?", start_date, end_date], :order=>"#{using} ASC") || []
      
      # build event hash
      calendar = {}
      notes.each do |n|
        d = n.send(using)
        next unless d
        calendar[d.strftime("%Y-%m-%d")] ||= []
        calendar[d.strftime("%Y-%m-%d")] << n
      end
  
      title = "#{_(Date::MONTHNAMES[date.mon])} #{date.year}"
  
      head_day_names = []
      0.upto(6) do |i|
        head_day_names << "<td>#{_(day_names[(i+week_start_day) % 7])}</td>"
      end
  
      content = []
      start_date.step(end_date,7) do |week|
        # each week
        content << "<tr class='body'>"
        week.step(week+6,1) do |day|
          # each day
          content << "<td#{ calendar_class(day,date)}#{day == Date.today ? " id='#{size}_today'" : "" }>#{on_day.call(calendar[day.strftime('%Y-%m-%d')], day)}</td>"
        end
        content << '</tr>'
      end
      
      render_to_string(:partial=>"calendar/#{size}", :locals=>{ :content=>content.join("\n"), 
                                                             :day_names=>head_day_names.join(""),
                                                             :title=>title, 
                                                             :date=>date,
                                                             :source_zip=>source[:zip],
                                                             :template_url=>opts[:template_url]})
    end
  end
  
  def unless_empty(obj)
    if obj.nil? || obj.empty?
      return ''
    else
      yield(obj)
    end
  end
  
  # Show a little [xx] next to the title if the desired language could not be found. You can
  # use a :text => '(lang)' option. The word 'lang' will be replaced by the real value.
  def check_lang(obj, opts={})
    wlang = (opts[:text] || '[#LANG]').sub('#LANG', obj.v_lang).sub('_LANG', _(obj.v_lang))
    obj.v_lang != lang ? "<#{opts[:tag] || 'span'} class='#{opts[:class] || 'wrong_lang'}'>#{wlang}</#{opts[:tag] || 'span'}>" : ""
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
      opts[:link] = (obj[:id] != @node[:id]) ? 'true' : nil
    end
    unless opts.include?(:project)
      opts[:project] = (obj.get_project_id != @node.get_project_id && obj[:id] != @node[:id]) 
    end
    title = opts[:text] || obj.version.title
    if opts[:project]
      title = "#{obj.project.name} / #{title}"
    end
    if opts[:link] && opts[:link] != 'false'
      link_opts = {}
      if opts[:link] == 'true'
        # nothing special for the link format
      elsif opts[:link] =~ /(\w+\.|)data$/
        link_opts[:mode] = $1[0..-2] if $1 != ''
        if obj.kind_of?(Document)
          link_opts[:format] = obj.c_ext
        else
          link_opts[:format] = 'html'
        end
      elsif opts[:link] =~ /(\w+)\.(\w+)/
        link_opts[:mode]   = $1
        link_opts[:format] = $2
      else
        link_opts[:mode]   = opts[:link]
      end
        
      title = "<a href='#{zen_path(obj, link_opts)}'>#{title}</a>"
    end
    title += check_lang(obj) unless opts[:check_lang] == 'false'
    "<span id='v_title#{obj.zip}'>#{title}</span>"
  end
  
  # TODO: test
  def show(obj, sym, opt={})
    return show_title(obj, opt) if sym == :v_title
    if opt[:as]
      key = "#{opt[:as]}#{obj.zip}.#{obj.v_number}"
      preview_for = opt[:as]
      opt.delete(:as)
    else
      key = "#{sym}#{obj.zip}.#{obj.v_number}"
    end
    if opt[:text]
      text = opt[:text]
      opt.delete(:text)
    else
      text = obj.send(sym)
      if text.blank? && sym == :v_summary
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
        text = "<code#{lang} class='full'>HEYHEY#{text.gsub("\n", '<br/>')}</code>"
      end
      text  = zazen(text, opt)
      klass = " class='zazen'"
    else
      klass = ""
    end
    if preview_for
      render_to_string :partial=>'nodes/show_attr', :locals=>{:id=>obj[:id], :text=>text, :preview_for=>preview_for, :key=>key, :klass=>klass,
                                                           :key_on=>"#{key}#{Time.now.to_i}_on", :key_off=>"#{key}#{Time.now.to_i}_off"}
    else
      "<div id='#{key}'#{klass}>#{text}</div>"
    end
  end
  
  # Display a selection 'box' for a given role (provided by the sym argument). Depending on the role type
  # this helper may render a checkbox list, a select menu or an input field for an id. Available choices
  # may be reduced by providing a list as :in argument : link_box('node', :calendars, :in=>[1,11]).
  def link_box(obj, sym, opt={})
    return "" # FIXME: BUT LINKS BACK INTO EDIT !
    node = instance_variable_get("@#{obj}".to_sym)
    method = "#{sym}_for_form".to_sym
    role = node.class.role[sym.to_s]
    unless role
      Node.logger.error "role #{sym} not found"
      return ''
    end
    setter = sym.to_s.singularize
    if role[:unique]
      # unique
      res = [select_id(obj,"#{setter}_id", :class=>role[:klass], :include_blank=>true)]
    else
      # many
      if opt[:in]
        ids = opt[:in].map{|i| i.to_i}
        list = node.send(method, :conditions=>["nodes.id IN (#{ids.join(',')})"]) || []
      else
        list = node.send(method) || []
      end
      res = list.inject([]) do |list, l|
        list << "<input type='checkbox' name='node[#{setter}_ids][]' value='#{l.zip}' class='box' #{ l[:link_id] ? "checked='1' " : ""}/>#{l.name}"
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
      title = "<li><b>#{_(sym.to_s)}</b></li>"
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
    @form_skins ||= secure(Skin) { Skin.find(:all, :order=>'name ASC') }.map {|r| r[:name]}
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
      _('img_private')
    elsif [obj.rgroup_id,obj.pgroup_id,obj.user_id].include?(1)
      _('img_public')
    else
      names = []
      names |= [obj.rgroup.name.limit(4)] if obj.rgroup
      names |= [obj.pgroup.name.limit(4)] if obj.pgroup
      names << obj.user.initials
      names.join(', ')
    end
    custom = obj.inherit != 1 ? "<span class='custom'>#{_('img_custom_inherit')}</span>" : ''
    "#{custom} #{readers}"
  end
  
  # Buttons are :edit, :add, :propose, :publish, :refuse, or :drive. :all = (:edit, :propose, :publish, :refuse, :drive)
  # TODO: implement multiple actions: :actions => 'edit,propose,delete'
  def node_actions(opts={})
    actions = (opts[:actions] || 'all').to_s
    actions = 'edit,propose,publish,refuse,drive' if actions == 'all'

    opts = { :node => @node }.merge(opts)
    text = opts[:text]
    node = opts[:node]
    # hash = { :node_id => node[:zip], :id => node.v_number } = this is bad: we should not preload a specific version when doing
                                                              # node actions
    hash = { :node_id => node[:zip], :id => 0 }
    
    res = []
    actions.split(',').map {|a| a.strip.to_sym}.each do |action|
      next unless node.can_apply?(action)
      case action
      when :edit
        res << "<a href='#{edit_version_url(hash)}' target='_blank' title='#{_('btn_title_edit')}' onclick=\"editor=window.open('#{edit_version_url(hash)}', '_blank', 'location=0,width=300,height=400,resizable=1');return false;\">" + 
               (text || _('btn_edit')) + "</a>"
      when :propose
        res << link_to((text || _("btn_propose")), propose_version_path(hash), :method => :put)
      when :publish
        res << link_to((text || _("btn_publish")), publish_version_path(hash), :method => :put)
      when :refuse
        res << link_to((text || _("btn_refuse")), refuse_version_path(hash), :method => :put)
      when :drive
        res << "<a href='#' title='#{_('btn_title_drive')}' onclick=\"editor=window.open('" + 
               edit_node_url(:id => node[:zip] ) + 
               "', '_blank', 'location=0,width=300,height=400,resizable=1');return false;\">" + 
               (text || _('btn_drive')) + "</a>"
      end
    end
    
    if res != []
      "<span class='actions'>#{res.join(" ")}</span>"
    else
      ""
    end
  end
  
  # TODO: test
  def version_form_action(action,version)
    if action == 'view'
      # FIXME
      link_to_function(_('btn_view'), "opener.Zena.version_preview(#{version.number});")
    else
      link_to_remote( _("btn_#{action}"), :url=>{:controller=>'versions', :action => action, :node_id => version.node[:zip], :id => version.number, :drive=>true}, :title=>_("btn_title_#{action}"), :method => :put ) + "\n"
    end
  end
  # TODO: test
  # show actions on versions
  def version_actions(version, opt={})
    opt = {:action=>:all}.merge(opt)
    return "" unless version.kind_of?(Version)
    
    node = version.node
    
    actions = []
    if opt[:action] == :view
      if (version.status != Zena::Status[:del] && version.status != Zena::Status[:red]) ||  (version[:user_id] == visitor.id )
        actions << version_form_action('view', version)
      end
    elsif opt[:action] == :all
      case version.status
      when Zena::Status[:pub]
        actions << version_form_action('unpublish',version) if node.can_unpublish?(version)
      when Zena::Status[:prop]
        actions << version_form_action('publish',version)
        actions << version_form_action('refuse',version)
      when Zena::Status[:prop_with]
        actions << version_form_action('publish',version)
        actions << version_form_action('refuse',version)
      when Zena::Status[:red]
        if version.user[:id] == visitor.id
          actions << version_form_action('publish',version)
          actions << version_form_action('propose',version)
          actions << version_form_action('remove',version)
        end
      when Zena::Status[:rep]
        actions << version_form_action('redit',version) if node.can_edit_lang?(version.lang)
        actions << version_form_action('publish',version)
        actions << version_form_action('propose',version)
        actions << version_form_action('destroy',version) if node.can_destroy_version?(version)
      when Zena::Status[:rem]
        actions << version_form_action('redit',version) if node.can_edit_lang?(version.lang)
        actions << version_form_action('publish',version)
        actions << version_form_action('propose',version)
        actions << version_form_action('destroy',version) if node.can_destroy_version?(version)
      when Zena::Status[:del]
        if (version[:user_id] == visitor[:id])
          actions << version_form_action('redit',version) if node.node.can_edit_lang?(version.lang)
        end
        actions << version_form_action('destroy',version) if node.can_destroy_version?(version)
      end
    end
    # [:edit, :publish, :remove, :propose, :refuse, :destroy]
    actions.join(" ")
  end
  
  # TODO: test
  def discussion_actions(discussion, opt={})
    opt = {:action=>:all}.merge(opt)
    return '' unless @node.can_drive?
    if opt[:action] == :view
      link_to_function(_('btn_view'), "opener.Zena.discussion_show(#{discussion[:id]}); return false;")
    elsif opt[:action] == :all
      if discussion.open?
        link_to_remote( _("img_open"), :url=>{:controller=>'discussions', :action => 'close' , :id => discussion[:id]}, :title=>_("btn_title_close_discussion")) + "\n"
      else                                                                   
        link_to_remote( _("img_closed"), :url=>{:controller=>'discussions', :action => 'open', :id => discussion[:id]}, :title=>_("btn_title_open_open_discussion")) + "\n"
      end +
      if discussion.can_destroy?                                                 
        link_to_remote( _("btn_remove"), :url=>{:controller=>'discussions', :action => 'remove', :id => discussion[:id]}, :title=>_("btn_title_destroy_discussion")) + "\n"
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
    (obj.traductions || []).each do |ed|
      trad_list << "<span#{ ed.lang == lang ? " class='current'" : ''}>" + link_to( _(ed[:lang]), zen_path(obj,:lang=>ed[:lang])) + "</span>"
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
  
  # show current path with links to ancestors
  def show_path(opts={})
    node = opts[:node] || @node
    tag  = opts[:tag] || 'li'
    join = opts[:join] || ''
    nav = []
    node.ancestors.each do |obj|
      nav << link_to(obj.name, zen_path(obj))
    end
    
    nav << "<a href='#{url_for(zen_path(node))}' class='current'>#{node.name}</a>"
    res = "#{res}<#{tag}>#{nav.join("</#{tag}><#{tag}>#{join}")}</#{tag}>"
  end
  
  # TODO: could be used by all helpers: faster then routes... Rename obj_link (is used to link to versions)
  # Used by zafu
  def node_link(opts={})
    options = {:node=>@node}.merge(opts)
    node = options.delete(:node)
    if href = options.delete(:href)
      node = node.find(:first, :relations=>[href]) || node unless href == 'self'
    end    
    return options[:text] unless node

    unless url_only = options.delete(:url_only)
      text = options.delete(:text) || node.version.title
      attributes = ""
      attributes += options[:class] ? " class='#{options.delete(:class)}'" : ''
      attributes += options[:id] ? " id='#{options.delete(:id)}'" : ''
    end
    url_only ? zen_path(node, options) :  "<a#{attributes} href='#{zen_path(node, options)}'>#{text}</a>"
  end
  
  # shows links for site features
  def show_link(link, opt={})
    case link
    when :admin_links
      [show_link(:home), show_link(:preferences), show_link(:comments), show_link(:users), show_link(:groups), show_link(:relations), show_link(:virtual_classes), show_link(:sites), show_link(:dev)].reject {|l| l==''}
    when :home
      return '' if visitor.is_anon?
      link_to_with_state(_('my home'), user_path(visitor))
    when :preferences
      return '' if visitor.is_anon?
      link_to_with_state(_('preferences'), preferences_user_path(visitor[:id]))
    when :comments
      return '' unless visitor.is_admin?
      link_to_with_state(_('manage comments'), :controller=>'comments', :action=>'list')
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
    <script src="/calendar/lang/calendar-#{l}-utf8.js" type="text/javascript"></script>
    <link href="/calendar/calendar-brown.css" media="screen" rel="Stylesheet" type="text/css" />
    #{javascript_start}
    Calendar._TT["DEF_DATE_FORMAT"] = "#{_('datetime')}";
    Calendar._TT["FIRST_DAY"] = #{_('week_start_day')};
    #{javascript_end}
    EOL
  end
  
  # show language selector
  def lang_links(opts={})
    if visitor.site[:monolingual]
      ""
    else
      if opts[:tag]
        tag_in  = "<#{opts[:tag]}>"
        tag_out = "</#{opts[:tag]}>"
      else
        tag_in = tag_out = ''
      end
      res = []
      visitor.site.lang_list.sort.each do |l|
        if l == lang
          if opts[:tag]
            res << "<#{opts[:tag]} class='on'>#{l}" + tag_out
          else
            res << "<em>#{l}</em>"
          end
        else
          if visitor.is_anon? && params[:prefix]
            res << tag_in + link_to(l, :overwrite_params => {:prefix => l}) + tag_out
          else
            res << tag_in + link_to(l, :overwrite_params => {:lang   => l}) + tag_out
          end
        end
      end
      res.join(opts[:join] || '')
    end
  end
  
  # TODO: test
  def search_box(opts={})
    render_to_string(:partial=>'search/form', :locals => {:ajax => opts[:ajax]})
  end
  
  private
  
  def calendar_get_options(size, source, template_url)
    case size
    when 'tiny'
      day_names = Date::ABBR_DAYNAMES
      on_day    = Proc.new { |events, date| events ? "<em>#{date.day}</em>" : date.day }
    when 'large'
      day_names = Date::DAYNAMES
      on_day    = Proc.new do |events, date|
        if events
          res = ["#{date.day}"]
          events.each do |e| #largecal_preview
            res << "<p>" + link_to_remote(e.v_title.limit(14), 
                                  :update=>'largecal_preview',
                                  :url=>{:controller=>'calendar', :action=>'notes', :id=>source[:zip], :template_url=>template_url, 
                                  :date=>date, :selected=>e[:zip] }) + "</p>"
          end
          res.join("\n")
        else
          date.day
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
      return select(obj,sym,  secure_write(klass) { klass.find(:all, :select=>'zip,name', :order=>'name ASC') }.map{|r| [r[:name], r[:zip]]}, { :include_blank => opt[:include_blank] })
    end
    node = instance_variable_get("@#{obj}".to_sym)
    if node
      id = node.send(sym.to_sym)
      current_obj = secure(Node) { Node.find(id) } if id
    else
      id = ''
      current_obj = nil
    end
    name_ref = "#{obj}_#{sym}_name"
    attribute = opt[:show] || 'name'
    if current_obj
      zip = current_obj[:zip]
      current = current_obj.send(attribute.to_sym)
      if current.kind_of?(Array)
        current = current.join('/')
      end
    else
      zip = ''
      current = ''
    end
    # we use both 'onChange' and 'onKeyup' for old javascript compatibility
    update = "new Ajax.Updater('#{name_ref}', '/nodes/attribute?node=' + this.value + '&attr=#{attribute}', {method:'get', asynchronous:true, evalScripts:true});"
    "<div class='select_id'><input type='text' size='8' id='#{obj}_#{sym}' name='#{obj}[#{sym}]' value='#{zip}' onChange=\"#{update}\" onKeyup=\"#{update}\"/>"+
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
