require 'digest/sha1'
require 'tempfile'

# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  include Zena::Acts::Secure
  include WillPaginate::ViewHelpers 

  @@_asset_methods = {}
  
  # define an asset method ('key' => method_name).
  def self.asset_method(opts)
    opts.each do |k,v|
      @@_asset_methods[k] = v
    end
  end
  
  def dom_id(node)
    if node.new_record?
      "#{params[:dom_id]}_form"
    elsif params[:action] == 'create' && !params[:udom_id]
      "#{params[:dom_id]}_#{node.zip}"
    else
      @dom_id || params[:udom_id] || params[:dom_id]
    end
  end
  
  # Enable translations for will_paginate
  def will_paginate_with_i18n(collection, options = {}) 
    will_paginate_without_i18n(collection, options.merge(:prev_label => _('img_prev_page'), :next_label => _('img_next_page'))) 
  end 

  alias_method_chain :will_paginate, :i18n
  
  # RJS to update a page after create/update/destroy
  def update_page_content(page, obj)
    if params[:t_id] && @node.errors.empty?
      @node = secure(Node) { Node.find_by_zip(params[:t_id])}
    end
    
    base_class = obj.kind_of?(Node) ? Node : obj.class
    
    if obj.new_record?
      # A. could not create object: show form with errors
      page.replace "#{params[:dom_id]}_form", :file => fullpath_from_template_url + "_form.erb"
    elsif @errors || !obj.errors.empty?
      # B. could not update/delete: show errors
      case params[:action]
      when 'destroy', 'drop'  
        page.insert_html :top, params[:dom_id], :inline => render_errors
      else
        page.replace "#{params[:dom_id]}_form", :file => fullpath_from_template_url + "_form.erb"
      end
    elsif params[:udom_id]
      if params[:udom_id] == '_page'
        # reload page
        page << "document.location.href = document.location.href;"
      else
        # C. update another part of the page
        if node_id = params[:u_id]
          if node_id.to_i != obj.zip
            if base_class == Node
              instance_variable_set("@#{base_class.to_s.underscore}", secure(base_class) { base_class.find_by_zip(node_id) })
            else
              instance_variable_set("@#{base_class.to_s.underscore}", secure(base_class) { base_class.find_by_id(node_id) })
            end
          end
        end
        page.replace params[:udom_id], :file => fullpath_from_template_url(params[:u_url]) + ".erb"
        if params[:upd_both]
          @dom_id = params[:dom_id]
          page.replace params[:dom_id], :file => fullpath_from_template_url + ".erb"
        end
        if params[:done] && params[:action] == 'create'
          page.toggle "#{params[:dom_id]}_form", "#{params[:dom_id]}_add"
          page << params[:done]
        elsif params[:done]
          page << params[:done]
        end
      end
    else
      # D. normal update
      #if params[:dom_id] == '_page'
      #  # reload page
      #  page << "document.location.href = document.location.href;"
      #  
      case params[:action]
      when 'edit'
        page.replace params[:dom_id], :file => fullpath_from_template_url + "_form.erb"
#        page << "$('#{params[:dom_id]}_form_t').focusFirstElement();"
      when 'create'
        pos = params[:position]  || :before
        ref = params[:reference] || "#{params[:dom_id]}_add"
        page.insert_html pos.to_sym, ref, :file => fullpath_from_template_url + ".erb"
        if obj.kind_of?(Node)
          @node = @node.parent.new_child(:class => @node.class)
        else
          instance_variable_set("@#{base_class.to_s.underscore}", obj.clone)
        end
        page.replace "#{params[:dom_id]}_form", :file => fullpath_from_template_url + "_form.erb"
        if params[:done]
          page << params[:done]
        else
          page.toggle "#{params[:dom_id]}_form", "#{params[:dom_id]}_add"
        end
      when 'update'
        page.replace params[:dom_id], :file => fullpath_from_template_url + ".erb"
        page << params[:done] if params[:done]
      when 'destroy'
        page.visual_effect :highlight, params[:dom_id], :duration => 0.3
        page.visual_effect :fade, params[:dom_id], :duration => 0.3
      when 'drop'
        case params[:done]
        when 'remove'
          page.visual_effect :highlight, params[:drop], :duration => 0.3
          page.visual_effect :fade, params[:drop], :duration => 0.3
        end
        page.replace params[:dom_id], :file => fullpath_from_template_url + ".erb"
      else
        page.replace params[:dom_id], :file => fullpath_from_template_url + ".erb"
      end
    end
  end
  
  # translation of static text using gettext
  # FIXME: I do not know why this is needed in order to have <%= _('blah') %> find the translations on some servers
  def _(str)
    NodesController.send(:_,str)
  end
  
  # TODO: use Rails native helper.
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
  
  def upload_form_tag(url_opts, html_opts = {})
    @uuid = UUIDTools::UUID.random_create.to_s.gsub('-','')
    html_opts.reverse_merge!(:multipart => true, :id => "UploadForm#{@uuid}")
    if html_opts[:multipart]
      html_opts[:onsubmit] = "submitUploadForm('#{html_opts[:id]}', '#{@uuid}');"
      url_opts[UPLOAD_KEY] = @uuid
    end
    if block_given?
      form_tag( url_opts, html_opts ) do |f|
        yield(f)
      end
    else
      form_tag( url_opts, html_opts )
    end
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
    
  # Add class='on' if the link points to the current page
  def link_to_with_state(*args)
    title, url, options = *args
    options ||= {}
    if request.path == url
      options[:class] = 'on'
    end
    link_to(title, url, options)
  end
  
  # unobtrusive link_to_remote
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
  
  # Quote for html values (input tag, alt attribute, etc)
  def fquote(text)
    text.to_s.gsub("'",'&apos;')
  end
  
  # TODO: see if this is still needed. Creates a pseudo random string to avoid browser side ajax caching
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
  
  # Return sprintf formated entry. Return '' for values eq to zero.
  def sprintf_unless_zero(fmt, value)
    value.to_f == 0.0 ? '' : sprintf(fmt, value)
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
  # ** [!14_pv!] inline image transformed to format 'pv' (class is also set to 'pv'). Formats are defined in #ImageBuilder.
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
    opt = {:images=>true, :pretty_code=>true, :output=>'html'}.merge(opt)
    no_p = opt.delete(:no_p)
    img = opt[:images]
    if opt[:limit]
      opt[:limit] -= 1 unless opt[:limit] <= 0
      paragraphs = text.split(/\n\n|\r\n\r\n/)
      if paragraphs.size > (opt[:limit]+1) && opt[:limit] != -1
        text = paragraphs[0..opt[:limit]].join("\r\n\r\n") + " &#8230;"
      end
    end
    opt[:node] ||= @node
    res = ZazenParser.new(text,:helper=>self).render(opt)
    if no_p && !text.include?("\n")
      res.gsub(%r{\A<p>|</p>\Z},'')
    else
      res
    end
  end
  
  # TODO: test
  def zazen_diff(text1, text2, opt={})
    HTMLDiff::diff(zazen(text1), zazen(text2))
  end

  # Parse the text in the given context (used by zazen)
  def make_asset(opts)
    asset_tag = opts[:asset_tag]
    if asset_method = @@_asset_methods[asset_tag]
      self.send(asset_method, opts)
    else
      # Unknown tag. Ignore
      "[#{asset_tag}]#{opts[:content]}[/#{asset_tag}]"
    end
  end
      
  
  # Creates a link to the node referenced by zip (used by zazen)
  def make_link(opts)
    # for latex refs, see http://www.tug.org/applications/hyperref/manual.html
    link_opts = {}
    if sharp = opts[:sharp]
      if sharp =~ /\[(.+?)\/(.*)\]/
        sharp_in, sharp = $1, $2
        sharp = sharp == '' ? 'true' : "[#{sharp}]"
        link_opts[:sharp_in] = sharp_in
      end
      if ['[id]', '[zip]'].include?(sharp)
        link_opts[:sharp] = 'true'
      else
        link_opts[:sharp] = sharp
      end
    end
    if opts[:id] =~ /(\d+)(_\w+|)(\.\w+|)/
      opts[:id]     = $1
      link_opts[:mode]   = ($2 != '') ? $2[1..-1] : nil
      link_opts[:format] = ($3 != '') ? $3[1..-1] : nil
    end
    node  = opts[:node] || secure(Node) { Node.find_by_zip(opts[:id]) }
    
    return "<span class='unknownLink'>#{_('unknown link')}</span>" unless node
    
    title = (opts[:title] && opts[:title] != '') ? opts[:title] : node.v_title
    
    link_opts[:format] = node.c_ext if link_opts[:format] == 'data'
    if opts[:id] && opts[:id][0..0] == '0'
      link_to title, zen_path(node, link_opts), :popup=>true
    else
      link_to title, zen_path(node, link_opts)
    end
  end
  
  # TODO: test
  def make_wiki_link(opts)
    l = opts[:node] ? opts[:node].version.lang : lang
    if opts[:url]
      if opts[:url][0..3] == 'http'
        "<a href='#{opts[:url]}' class='wiki'>#{opts[:title]}</a>"
      else
        "<a href='http://#{l}.wikipedia.org/wiki/#{opts[:url]}' class='wiki'>#{opts[:title]}</a>"
      end
    else
      "<a href='http://#{l}.wikipedia.org/wiki/Special:Search?search=#{CGI::escape(opts[:title])}' class='wiki'>#{opts[:title]}</a>"
    end
  end
  
  # Create an img tag for the given image. See ApplicationHelper#zazen for details.
  def make_image(opts)
    id, style, link, mode, title = opts[:id], opts[:style], opts[:link], opts[:mode], opts[:title]
    mode ||= 'std' # default mode
    img = opts[:node] || secure(Document) { Document.find_by_zip(id) }
    
    return "<span class='unknownLink'>#{_('unknown document')}</span>" unless img
    
    if !opts[:images].nil? && !opts[:images]
      return "[#{_('image')}: #{img.v_title}]"
    end
    title = img.v_summary if title == ""
    
    image = img_tag(img, :mode=>mode)
    
    unless link
      if id[0..0] == "0" || !img.kind_of?(Image)
        # if the id starts with '0' or it is not an Image, link to data
        link = zen_path(img, :format => img.c_ext)
        link_tag = "<a class='popup' href='#{link}' target='_blank'>"
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
    
    if link.nil? || image[0..3] == '[:::' # do not link on placeholders
      prefix + image + suffix
    elsif link =~ /^\d+/
      prefix + make_link(:id=>link,:title=>image) + suffix
    else
      link = "http://#{link}" unless link =~ %r{(^/|.+://.+)}
      link_tag ||= "<a href='#{link}'>"
      prefix + link_tag + image + "</a>" + suffix
    end
  end
  
  # Create a gallery from a list of images. See ApplicationHelper#zazen for details.
  def make_gallery(ids=[], opts={})
    if ids == []
      images = secure(Image) { Image.find(:all, :conditions => ["parent_id = ?", (opts[:node] || @node)[:id]], :order => "position ASC, name ASC")}
    else
      ids = ids.map{|i| i.to_i}
      images = ids == [] ? nil : secure(Document) { Document.find(:all, :conditions=>"zip IN (#{ids.join(',')})") }
      # order like ids :
      images.sort! {|a,b| ids.index(a[:zip].to_i) <=> ids.index(b[:zip].to_i) } if images
    end
    
    render_to_string( :partial=>'nodes/gallery', :locals=>{:gallery=>images} )
  end
  
  # Create a table from an attribute
  def make_table(opts)
    style, node, attribute, title, table = opts[:style], opts[:node], opts[:attribute], opts[:title], opts[:table]
    attribute = "d_#{attribute}" unless ['v_', 'd_'].include?(attribute[0..1])
    case (style || '').sub('.', '')
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
      prefix = ''
      suffix = ''
    end
    
    if node.can_write?
      prefix << "<div class='table_add'>"
      prefix << link_to_remote("<img src='/images/column_add.png' alt='#{_('add column')}'/>", 
                                :url => "/nodes/#{node.zip}/table_update?add=column&attr=#{attribute}")
      prefix << link_to_remote("<img src='/images/column_delete.png' alt='#{_('add column')}'/>", 
                                :url => "/nodes/#{node.zip}/table_update?remove=column&attr=#{attribute}")
      prefix << link_to_remote("<img src='/images/row_add.png' alt='#{_('add column')}'/>", 
                                :url => "/nodes/#{node.zip}/table_update?add=row&attr=#{attribute}")
      prefix << link_to_remote("<img src='/images/row_delete.png' alt='#{_('add column')}'/>", 
                                :url => "/nodes/#{node.zip}/table_update?remove=row&attr=#{attribute}")
      prefix << "</div>"
    end
    
    table ||= get_table_from_json(node, attribute)
    
    prefix + render_to_string( :partial=>'nodes/table', :locals=>{:table=>table, :node=>node, :attribute=>attribute}) + suffix
  rescue JSON::ParserError
    "<span class='unknownLink'>could not build table from text</span>"
  end

  def list_nodes(ids=[], opts={})
    style = opts[:style] || ''
    node  = opts[:node] || @node
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
    if ids == []
      docs = node.find(:all, 'documents')
    elsif ids[0] == "d"
      docs = node.find(:all, 'documents where kpath not like "NDI%"')
    elsif ids[0] == "i"
      docs = node.find(:all, 'images')
    else
      ids = ids.map{|i| i.to_i}
      docs = ids == [] ? nil : secure!(Document) { Document.find(:all, :order=>'name ASC', :conditions=>"zip IN (#{ids.join(',')})") }
      # order like ids :
      docs.sort! {|a,b| ids.index(a[:zip].to_i) <=> ids.index(b[:zip].to_i) } if docs
    end
    return '' unless docs
    prefix + render_to_string( :partial=>'nodes/list_nodes', :locals=>{:docs=>docs}) + suffix
  rescue
    '[no document found]'
  end
  
  # TODO: refactor with new RedCloth
  def add_place_holder(str)
    @placeholders ||= {}
    key = "[:::#{self.object_id}.#{@placeholders.keys.size}:::]"
    @placeholders[key] = str
    key
  end
  
  # Replace placeholders by their real values
  def replace_placeholders(str)
    (@placeholders || {}).each do |k,v|
      str.gsub!(k,v)
    end
    str
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
      [:src, :width, :height, :alt, :id, :class, :style, :border].each do |k|
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
      
      res[:alt]   = opts[:alt] || fquote(obj.v_title)
      res[:src]   = data_path(obj, :mode => (format[:size] == :keep ? nil : format[:name]), :host => opts[:host])
      res[:class] = opts[:class] || format[:name]
      
      # compute image size
      res[:width]  = content.width(format)
      res[:height] = content.height(format)
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
      img = ImageBuilder.new(:path=>"#{RAILS_ROOT}/public#{res[:src]}", :width=>32, :height=>32)
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
  
  
  # return a readable text version of a file size
  # TODO: use number_to_human_size instead
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
  
  # list of page numbers links
  def page_numbers(current, count, join_string = nil, max_count = nil)
    max_count ||= 10
    join_string ||= ''
    join_str = ''
    if count <= max_count
      1.upto(count) do |p|
        yield(p, join_str)
        join_str = join_string
      end
    else
      # only first pages (centered around current page)
      if current - (max_count/2) > 0
        finish = [current + (max_count/2),count].min
      else
        finish = [max_count,count].min
      end
      
      start  = [finish - max_count + 1,1].max
      
      start.upto(finish) do |p|
        yield(p, join_str)
        join_str = join_string
      end
    end
  end
  
  # main node before ajax stuff (the one in browser url)
  def start_node
    @start_node ||= if params[:s]
      secure!(Node) { Node.find_by_zip(params[:s]) }
    else
      @node
    end
  end
  
  # default date used to filter events in templates
  def main_date
    # TODO: timezone for @date ?
    # .to_utc(_('datetime'), visitor.tz)
    @date ||= params[:date] ? Date.parse(params[:date]) : Date.today
  end
  
  def cal_day_names(size)
    if size == :tiny
      day_names = Date::ABBR_DAYNAMES
    else
      day_names = Date::DAYNAMES
    end
    week_start_day = _('week_start_day').to_i
    res = ""
    0.upto(6) do |i|
      j = (i+week_start_day) % 7
      if j == 0
        html_class = " class='sun'"
      elsif j == 6
        html_class = " class='sat'"
      end
      res << "<td#{html_class}>#{_(day_names[j])}</td>"
    end
    res
  end
  
  # find start and end dates for a calendar showing a specified date
  def cal_start_end(date, type=:month)
    week_start_day = _('week_start_day').to_i
    
    case type
    when :week
      # week
      start_date  = date
      end_date    = date
    else
      # month
      start_date  = Date.civil(date.year, date.mon, 1)
      end_date    = Date.civil(date.year, date.mon, -1)
    end  
    start_date -= (start_date.wday + 7 - week_start_day) % 7
    end_date   += (6 + week_start_day - end_date.wday) % 7
    [start_date, end_date]
  end
  
  def cal_class(date, ref)
    @today ||= Date.today
    case date.wday
    when 6
      s = "sat"
    when 0
      s = "sun"
    else
      s = ""
    end
    s +=  'other' if date.mon != ref.mon
    s = s == '' ? [] : [s]
    s <<  'today' if date == @today
    s <<  'ref' if date == ref
    s == [] ? '' : " class='#{s.join(' ')}'"
  end
  
  # Yield block for every week between 'start_date' and 'end_date' with a hash of days => events.
  def cal_weeks(date_attr, list, start_date, end_date, hours = nil)
    # build event hash
    cal_hash = {}
    if hours
      # hours should contain 0 and should be sorted
      # [0,12] ==> 0  => dates from 00:00 to 11:59
      #            12 => dates from 12:00 to 23:59
      
      (list || []).each do |n|
        d = n.send(date_attr)
        next unless d
        hours.reverse_each do |h|
          if d.hour >= h
            d = d - (d.hour - h) * 3600 # too bad Time does not have an hour= method, we could have written d.hour = h
            n.send("#{date_attr}=", d) # we need this to properly display hour class in ajax return
            h_list = cal_hash[d.strftime("%Y-%m-%d %H")] ||= []
            h_list << n
            break
          end
        end
      end
      
    else
      (list || []).each do |n|
        d = n.send(date_attr)
        next unless d
        cal_hash[d.strftime("%Y-%m-%d 00")] ||= []
        cal_hash[d.strftime("%Y-%m-%d 00")] << n
      end
    end
    
    start_date.step(end_date,7) do |week|
      # each week
      yield(week, cal_hash)
    end
  end
  
  # display a calendar cell to assign 'node_a' to 'node_b' with 
  # A (target_zip)
  # ... B (source_zip) ---> reference_to A, B, C, D
  #     <r:calendar assign='reference' to='main' />
  def cal_assign_cell(node, role, remove_used, target_zip=nil, date=nil, template_url=nil)
    date         ||= Time.parse(params[:date])
    target_zip   ||= params[:s]
    template_url ||= params[:t_url]
    state = node.linked_node ? (node.linked_node.zip ==  target_zip.to_i ? 'on' : 'used') : 'free'
    title = node.linked_node ? node.linked_node.v_title : _('free')
    hour  = date.strftime('%H')
    full_dom_id = "#{node.zip}_#{target_zip}_#{date.to_i}"
    res = "<li id='#{full_dom_id}' class='hour_#{hour} #{state}'>"
    
    if state == 'used' && remove_used.nil?
      res << title
    else
      opts = {:url => "/nodes/#{node.zip}?node[link][#{role}][date]=#{date.strftime("%Y-%m-%d+%H")}&node[link][#{role}][other_id]=#{state == 'free' ? target_zip : ''}&s=#{target_zip}&dom_id=#{full_dom_id}&t_url=#{CGI.escape(template_url)}&date=#{date.strftime("%Y-%m-%d+%H")}", :method => :put}
      if state == 'used' && remove_used == 'warn'
        opts[:confirm] = _("Delete relation '%{role}' between '%{source}' and '%{target}' ?") % {:role => role, :source => node.v_title, :target => node.linked_node.v_title}
      end
      res << link_to_remote(title, opts)
    end
    res << "</li>"
    res
  end
  
  # Show a little [xx] next to the title if the desired language could not be found. You can
  # use a :text => '(lang)' option. The word 'lang' will be replaced by the real value.
  def check_lang(obj, opts={})
    wlang = (opts[:text] || '[#LANG]').sub('#LANG', obj.v_lang).sub('_LANG', _(obj.v_lang))
    obj.v_lang != lang ? "<#{opts[:wrap] || 'span'} class='#{opts[:class] || 'wrong_lang'}'>#{wlang}</#{opts[:wrap] || 'span'}>" : ""
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
      # we show the link if the object is not the current node or when it is being created by zafu ajax.
      opts[:link] = (obj[:id] != @node[:id] || params[:t_url]) ? 'true' : nil
    end
    
    unless opts.include?(:project)
      opts[:project] = (obj.get_project_id != @node.get_project_id && obj[:id] != @node[:id]) 
    end
    
    title = opts[:text] || obj.version.title
    if opts[:project] && project = obj.project
      title = "#{project.name} / #{title}"
    end
    
    title += check_lang(obj) unless opts[:check_lang] == 'false'
    title  = "<span id='v_title#{obj.zip}'>#{title}</span>"
    
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
            link_opts[:format] = obj.c_ext
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
  
  # TODO: is this still used ?
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
        text = "<code#{lang} class='full'>#{text}</code>"
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
  
  #TODO: test
  def site_tree(obj=nil)
    skip  = obj ? obj[:id] : nil
    base  = secure!(Node) { Node.find(visitor.site[:root_id]) }
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
      names |= [truncate(obj.rgroup.name,7)] if obj.rgroup
      names |= [truncate(obj.pgroup.name,7)] if obj.pgroup
      names << obj.user.initials
      names.join(', ')
    end
    custom = obj.inherit != 1 ? "<span class='custom'>#{_('img_custom_inherit')}</span>" : ''
    "#{custom} #{readers}"
  end
  
  # Actions that appear on the web page
  def node_actions(opts={})
    actions = (opts[:actions] || 'all').to_s
    actions = 'edit,propose,publish,refuse,drive' if actions == 'all'

    node = opts[:node] || @node
    return '' if node.new_record?
    publish_after_save = opts[:publish_after_save]
    res = actions.split(',').reject do |action|
      !node.can_apply?(action.to_sym)
    end.map do |action|
      node_action_link(action, node, publish_after_save)
    end.join(" ")
    
    if res != ""
      "<span class='actions'>#{res}</span>"
    else
      ""
    end
  end
  
  # TODO: test
  def node_action_link(action, node, publish_after_save)
    case action
    when 'edit'
      url = edit_version_url(:node_id => node[:zip], :id => 0)
      "<a href='#{url}#{publish_after_save ? "?pub=#{publish_after_save}" : ''}' target='_blank' title='#{_('btn_title_edit')}' onclick=\"editor=window.open('#{url}#{publish_after_save ? "?pub=#{publish_after_save}" : ''}', \'#{current_site.host}#{node[:zip]}\', 'location=0,width=300,height=400,resizable=1');return false;\">" + 
             _('btn_edit') + "</a>"
    when 'drive'
      "<a href='#' title='#{_('btn_title_drive')}' onclick=\"editor=window.open('" + 
             edit_node_url(:id => node[:zip] ) + 
             "', '_blank', 'location=0,width=300,height=400,resizable=1');return false;\">" + 
             _('btn_drive') + "</a>"
    else
      link_to( _("btn_#{action}"), {:controller=>'versions', :action => action, :node_id => node[:zip], :id => 0}, :title=>_("btn_title_#{action}"), :method => :put )
    end
  end
  
  # Actions that appear in the drive popup versions list
  def version_actions(version, opts={})
    return "" unless version.kind_of?(Version)
    # 'view' ?
    actions = (opts[:actions] || 'all').to_s
    actions = 'destroy_version,remove,redit,unpublish,propose,refuse,publish' if actions == 'all'
    
    node = version.node
    
    actions.split(',').reject do |action|
      action.strip!
      if action == 'view'
        !node.can_apply?('publish', version)
      else
        !node.can_apply?(action.to_sym, version)
      end
    end.map do |action|
      version_action_link(action, version)
    end.join(' ')
  end
  
  # TODO: test
  def version_action_link(action,version)
    if action == 'view'
      # FIXME
      link_to_function(_('btn_view'), "opener.Zena.version_preview(#{version.number});")
    else
      link_to_remote( _("btn_#{action}"), :url=>{:controller=>'versions', :action => action, :node_id => version.node[:zip], :id => version.number, :drive=>true}, :title=>_("btn_title_#{action}"), :method => :put ) + "\n"
    end
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
        link_to_remote( _("img_closed"), :url=>{:controller=>'discussions', :action => 'open', :id => discussion[:id]}, :title=>_("btn_title_open_discussion")) + "\n"
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
    when :zena_up
      return '' unless ENABLE_ZENA_UP && visitor.is_admin?
      link_to_with_state(_('update zena'), zena_up_sites_path)
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
    if opts[:wrap]
      tag_in  = "<#{opts[:wrap]}>"
      tag_out = "</#{opts[:wrap]}>"
    else
      tag_in = tag_out = ''
    end
    res = []
    visitor.site.lang_list.each do |l|
      if l == lang
        if opts[:wrap]
          res << "<#{opts[:wrap]} class='on'>#{l}" + tag_out
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
  
  # TODO: test
  def search_box(opts={})
    render_to_string(:partial=>'search/form', :locals => {:ajax => opts[:ajax], :type => opts[:type]})
  end
  
  private
  
  # This lets helpers render partials
  # TODO: make sure this is the best way to handle this problem.
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
      return select(obj,sym,  secure_write!(klass) { klass.find(:all, :select=>'zip,name', :order=>'name ASC') }.map{|r| [r[:name], r[:zip]]}, { :include_blank => opt[:include_blank] })
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
  
  # Group an array of records by key.
  def group_array(list)
    groups = []
    h = {}
    list.each do |e|
      key = yield(e)
      unless group_id = h[key]
        h[key] = group_id = groups.size
        groups << []
      end
      groups[group_id] << e
    end
    groups
  end
  
  def sort_array(list)
    list.sort do |a,b|
      va = yield([a].flatten[0])
      vb = yield([b].flatten[0])
      if va && vb
        va <=> vb
      elsif va
        1
      elsif vb
        -1
      else
        0
      end
    end
  end
  
  def min_array(list)
    list.flatten.min do |a,b|
      va = yield(a)
      vb = yield(b)
      if va && vb
        va <=> vb
      elsif va
        1
      elsif vb
        -1
      else
        0
      end
    end
  end
  
  def max_array(list)
    list.flatten.min do |a,b|
      va = yield(a)
      vb = yield(b)
      if va && vb
        vb <=> va
      elsif vb
        1
      elsif va
        -1
      else
        0
      end
    end
  end
end

Bricks::Patcher.apply_patches