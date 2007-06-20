require 'gettext/rails'

class ApplicationController < ActionController::Base
  init_gettext 'zena'
  helper_method :prefix, :zen_path, :zen_url, :data_path, :node_url, :notes, :error_messages_for, :render_errors, :processing_error
  helper_method :get_template_text, :template_url_for_asset, :save_erb_to_url, :lang, :visitor, :fullpath_from_template_url
  before_filter :authorize
  before_filter :set_lang
  after_filter  :set_encoding
  layout false
  
  private
  
  
    # TODO: test
    # Our own handling of exceptions
    def rescue_action_in_public(exception)
      case exception
      when ActiveRecord::RecordNotFound, ActionController::UnknownAction
        render_404(exception)
      else
        render_500(exception)
      end
    end
  
    # TODO: test
    def render_404(exception)
      respond_to do |format|
        format.html { redirect_to not_found_url } # FIXME: can we keep some info on the '404' status ?
        format.all  { render :nothing => true, :status => "404 Not Found" }
      end
    end
  
    # TODO: test
    def render_500(exception)
      respond_to do |format|
        format.html { render :file    => "#{RAILS_ROOT}/public/500.html", :status => '500 Error' }
        format.all  { render :nothing => true, :status => "500 Error" }
      end
    end
  
    # TODO: test
    def visitor
      @visitor ||= returning(User.make_visitor(:host => request.host, :id => session[:user])) do |user|
        if session[:user] != user[:id]
          # changed user (login/logout)
          session[:user] = user[:id]
          session[:lang] = user.lang
        end
      end
    end
        
    # TODO: test
    def lang
      visitor.lang
    end
    
    def render_and_cache(options={})
    
      opts = {:skin=>@node[:skin], :cache=>true}.merge(options)
      opts[:mode  ] ||= params[:mode]
      opts[:format] ||= params[:format]
      
      # cleanup before rendering
      params.delete(:mode)
      params.delete(:format)
      
      @section = @node.section
      # init default date used for calendars, etc
      @date  ||= params[:date] ? parse_date(params[:date]) : Date.today
      render :file => template_url(opts), :layout=>false
    
      cache_page if opts[:cache]
    end
  
    # Cache page content into a static file in the current sites directory : SITES_ROOT/test.host/public
    def cache_page(opts={})
      return unless perform_caching && caching_allowed(:authenticated => opts.delete(:authenticated))
      opts = {:expire_after  => nil,
              :path          => (current_site.public_path + page_cache_file),
              :content_data  => response.body   
              }.merge(opts)
      secure(CachedPage) { CachedPage.create(opts) }
    end
  
    # Return true if we can cache the current page
    def caching_allowed(opts = {})
      return false if current_site.authentication?
      opts[:authenticated] || visitor.is_anon?
    end
  
    # Cache file path that reflects the called url
    def page_cache_file
      path = url_for(:only_path => true, :skip_relative_url_root => true)
      path = ((path.empty? || path == "/") ? "/index" : URI.unescape(path))
      path << ".#{params[:format] || 'html'}" unless path =~ /\.#{params[:format]}$/
      path
    end
  
    # Find the best template for the current node's skin, node's class, format and mode. The template
    # files are searched first into 'sites/shared/views/templates/fixed'. If the templates are not found
    # there, they are searched in the database and compiled into 'app/views/templates/compiled'.
    def template_url(opts={})
      @skin_name = opts[:skin]   || (@node ? @node[:skin] : nil) || 'default'
      @skin_name = @skin_name.gsub(/[^a-zA-Z]/,'') # security
      mode      = opts[:mode]
      format    = opts[:format] || 'html'
      klass     = @node.vclass
      
      # possible classes for the master template :
      klasses = []
      klass.kpath.split(//).each_index { |i| klasses << klass.kpath[0..i] }
      
      template = secure(Template) { Template.find(:first, 
        :conditions => ["tkpath IN (?) AND format = ? AND mode #{mode ? '=' : 'IS'} ? AND template_contents.node_id = nodes.id", klasses, format, mode],
        :from       => "nodes, template_contents",
        :select     => "nodes.*, template_contents.skin_name, template_contents.klass, (template_contents.skin_name = #{@skin_name.inspect}) AS skin_ok",
        :order      => "length(tkpath) DESC, skin_ok DESC"
      )}
      
      # FIXME use a default fixed template.
      raise ActiveRecord::RecordNotFound unless template
      
      mode      = "_#{mode}" if mode
      lang_path = session[:dev] ? 'dev' : lang
      
      skin_path = "/#{@skin_name}/#{template[:klass]}#{mode}.#{format}"
      fullpath  = skin_path + "/#{lang_path}/_main.erb"
      url       = SITES_ROOT + current_site.zafu_path + fullpath

      if !File.exists?(url)
        # no template ---> render
        # TODO: test
        
        # set the places to search for the included templates
        # FIXME: there might be a better way to do this. In a hurry, fix later.
        @skin       = {}
        secure(Skin) { Skin.find(:all, :order=>'position ASC, name ASC') }.each do |s|
          @skin[s.name] = s
        end
        @skin_names = [@skin_name, @skin.keys].flatten.uniq
        @skin_link  = zen_path(@skin[@skin_name]) # used to link from <r:design/> zafu tag
        @expire_with_nodes = {}
        @renamed_assets    = {}
        
        response.template.instance_variable_set(:@session, session)
        skin_helper = response.template
        # [1..-1] = drop leading '/' so find_template_document searches in the current skin first
        res = ZafuParser.new_with_url(skin_path[1..-1], :helper => skin_helper).render
        
        if session[:dev] && mode != '_popup_layout'
          # add template edit buttons
          used_nodes = @expire_with_nodes.merge(@renamed_assets)
          div = "<div id='dev'><ul>" + used_nodes.map do |k,n| "<li>#{skin_helper.send(:node_actions, :node=>n)} #{skin_helper.send(:link_to,k,zen_path(n))}</li>"
          end.join("") + "<li><span class='actions'><a href='/users/#{visitor[:id]}/swap_dev'>#{_('turn dev off')}</a></span></li>"
          res.sub!('</body>', "#{div}</body>")
        end
        
        secure(CachedPage) { CachedPage.create(
          :path            => (current_site.zafu_path + fullpath),
          :expire_after    => nil,
          :expire_with_ids => @expire_with_nodes.values.map{|n| n[:id]},
          :content_data    => res) }
      end
    
      return url
    end
  
    # Return a template's content from an url. If the url does not start with a '/', we try by replacing the
    # first element with the current skin_name and if it does not work, we try with the full url. If the url
    # start with a '/' we use the full url directly.
    # tested in MainControllerTest
    def get_template_text(opts)
      return nil unless res = find_template_document(opts)
      doc, url = *res
      # TODO: could we use this for caching or will we loose dynamic context based loading ?
      @expire_with_nodes[url] = doc
      text = session[:dev] ? doc.version.text : doc.version(:pub).text
      return text, url
    end

    # TODO: implement
    def template_url_for_asset(opts)
      return nil unless res = find_template_document(opts)
      asset, url = *res
      @renamed_assets[url] = asset
      if asset.public? && !current_site.authentication?
        # force the use of a cacheable path for the data, even when navigating in '/oo'
        data_path(asset, :prefix=>lang)
      else
        data_path(asset, :prefix=>prefix)
      end
    rescue ActiveRecord::RecordNotFound
      return nil
    end
    
    # opts should contain :current_template and :src
    def find_template_document(opts)
      src    = opts[:src].split('.')
      mode   = src.pop
      src    = src.join('.')
      folder = (opts[:current_folder] && opts[:current_folder] != '') ? opts[:current_folder].split('/') : []
      @skin ||= {}
      
      if src =~ /^\//
        # starts with '/' : look here first
        url = src[1..-1].split('/')
        skin_names = [url.shift] + @skin_names
      else
        # does not start with '/' : look in skin_names first
        url = folder + src.split('/')
        skin_names = @skin_names
        skin_names << url.shift if url.size > 1
      end
      document = skin_name = nil
      
      skin_names.uniq.each do |skin_name|
        
        next unless skin = @skin[skin_name] ||= (secure(Skin) { Skin.find_by_name(skin_name) } rescue nil)
        path = (skin.fullpath.split('/') + url).join('/')
        break if document = secure(TextDocument) { TextDocument.find_by_path(path) } rescue nil 
        path = (skin.fullpath(true).split('/') + url).join('/') # rebuild fullpath
        break if document = secure(TextDocument) { TextDocument.find_by_path(path) } rescue nil
      end
      return document ? [document, ([skin_name] + url).join('/') + ".#{mode}"] : nil
    end
  
    # TODO: test
    def save_erb_to_url(template, template_url)
      path = fullpath_from_template_url(template_url) + ".erb"
      FileUtils.mkpath(File.dirname(path)) unless File.exists?(File.dirname(path))
      File.open(path, "wb") { |f| f.syswrite(template) }
      ""
    end
  
    # TODO: test
    def fullpath_from_template_url(template_url=params[:template_url])
      if template_url =~ /\.\.|[^\w\._\/]/
        raise Zena::AccessViolation.new("'template_url' contains illegal characters : #{template_url.inspect}")
      end
      
      template_url = template_url[1..-1].split('/')
      path = "/#{template_url[0]}/#{template_url[1]}/#{session[:dev] ? 'dev' : lang}/#{template_url[2..-1].join('/')}"

      "#{SITES_ROOT}/#{current_site.host}/zafu#{path}"
    end
  
    # Require a login for authenticated navigation (with '/oo' prefix) or for any content if the site's 'authorize'
    # attribute is true.
    def authorize
      return true if params[:controller] == 'session' && ['create', 'new', 'destroy'].include?(params[:action])
      
      # Require a login if :
      # 1. site forces authentication 
      if (current_site.authentication? && visitor.is_anon?)
        return false unless do_login
      end
      
      # Redirect if :
      # 1. navigating out of '/oo' but logged in and format is not data
      if (params[:prefix] && params[:prefix] != AUTHENTICATED_PREFIX && !visitor.is_anon?)
        format = params[:format] || (params[:path] || '').split('.').last
        return true unless ['xml','html', nil].include?(format)
        session[:lang] = params[:prefix]
        redirect_to request.parameters.merge(:prefix=>AUTHENTICATED_PREFIX) and return false
      end
    end
    
    def do_login
      if current_site[:http_auth]
        session[:after_login_url] = request.parameters
        basic_auth_required do |username, password| 
          if user = User.make_visitor(:login => username, :password => password, :site => current_site)
            successful_login(user)
          end
        end
      else
        session[:after_login_url]   ||= request.parameters
        flash[:notice] = _("Please log in")
        redirect_to login_path and return false
      end
    end
    
    def successful_login(user)
      session[:user] = user[:id]
      @visitor = user
      @visitor.visit(@visitor)
      # reset session lang, will be set from user on next request/filter
      session[:lang] = nil
      after_login_url = session[:after_login_url]
      session[:after_login_url] = nil
      if current_site[:http_auth] && params[:controller] != 'session'
        # no need to redirect
      else
        redirect_to after_login_url || user_path(visitor)
        return false
      end
    end
    
    # code adapted from Stuart Eccles from act_as_railsdav plugin
    def basic_auth_required(realm=current_site.name) 
      username, passwd = get_auth_data
      # check if authorized
      # try to get user
      if yield username, passwd
        true
      else
        # the user does not exist or the password was wrong
        headers["Status"] = "Unauthorized" 
        headers["WWW-Authenticate"] = "Basic realm=\"#{realm}\""
        
        # require login
        if current_site.authentication?
          render :nothing => true, :status => 401
        else
          redirect_url = session[:after_login_url] ? url_for(session[:after_login_url].merge(:prefix => session[:lang])) : '/'
          render :text => "
          <html>
            <head>
            <script type='text/javascript'>
            <!--
            window.location = '#{redirect_url}'
            //-->
            </script>
            </head>
            <body>redirecting to <a href='#{redirect_url}'>#{redirect_url}</a></body>
            </html>", :status => 401
        end
        false
      end 
    end 
    
    # code from Stuart Eccles from act_as_railsdav plugin
    def get_auth_data 
      user, pass = '', '' 
      # extract authorisation credentials 
      if request.env.has_key? 'X-HTTP_AUTHORIZATION' 
        # try to get it where mod_rewrite might have put it 
        authdata = request.env['X-HTTP_AUTHORIZATION'].to_s.split 
      elsif request.env.has_key? 'HTTP_AUTHORIZATION' 
        # this is the regular location 
        authdata = request.env['HTTP_AUTHORIZATION'].to_s.split  
      end 

      # at the moment we only support basic authentication 
      if authdata and authdata[0] == 'Basic' 
        user, pass = Base64.decode64(authdata[1]).split(':')[0..1] 
      end 
      return [user, pass] 
    end
    
  
    # Choose best language to display content.
    # 1. 'test.host/oo?lang=en' use 'lang', redirect without lang
    # 2. 'test.host/oo' use session[:lang]
    # 3. 'test.host/fr' use the request prefix
    # 4. 'test.host/'   use current session lang if any
    # 5. 'test.host/'   use HTTP_ACCEPT_LANGUAGE
    # 6. 'test.host/'   use default language
    def set_lang
      [
        params[:lang], 
        params[:prefix] == AUTHENTICATED_PREFIX ? nil : params[:prefix],
        (visitor.is_anon? ? nil : visitor.lang), # visitor.lang comes before session[:lang] and before http headers if logged in
        session[:lang],
        (request.headers['HTTP_ACCEPT_LANGUAGE'] || '').split(',').sort {|a,b| (b.split(';q=')[1] || 1.0).to_f <=> (a.split(';q=')[1] || 1.0).to_f }.map {|l| l.split(';')[0].split('-')[0] },
        (visitor.is_anon? ? visitor.lang : nil), # anonymous user's lang comes last
      ].compact.flatten.uniq.each do |l|
        if current_site.lang_list.include?(l)
          session[:lang] = l
          break
        end
      end
      
      session[:lang] ||= current_site[:default_lang]
      
      visitor.lang = session[:lang] # FIXME: this should not be needed, use global GetText.get_locale...
      GetText.set_locale_all(session[:lang])
      
      if params[:controller] == 'nodes'
        if params[:prefix] == AUTHENTICATED_PREFIX && visitor.is_anon?
          return false unless do_login
        end

        case params[:action]
        when 'index'
          redirect_url = "/#{prefix}" if params[:prefix] != prefix || params[:lang]
        when 'show'
          redirect_url = if !params[:path] || 
                            # fr/texdocument5.css is allowed even if AUTHENTICATED to allow caching of data
                            (params[:prefix] != prefix && (params[:format] == 'html' || !current_site.lang_list.include?(params[:prefix]))) || params[:lang]
            if params[:id]
              zen_path(secure(Node) { Node.find_by_zip(params[:id]) })
            else
              request.parameters.merge(:prefix => prefix, :lang => nil)
            end
          end 
        end
        
        if redirect_url
          redirect_to redirect_url and return false
        end
      elsif params[:lang]
        redirect_url = params
        redirect_url.delete(:lang)
        redirect_to redirect_url and return false
      end
      true
    end
  
    def set_encoding
      headers['Content-Type'] ||= 'text/html'
      if headers['Content-Type'].starts_with?('text/') and !headers['Content-Type'].include?('charset=')
        headers['Content-Type'] += '; charset=utf-8'
      end
    end
  
    # Parse date : return an utc date from a string
    def parse_date(datestr, fmt=_('datetime'))
      elements = datestr.split(/(\.|\-|\/|\s|:)+/)
      format = fmt.split(/(\.|\-|\/|\s|:)+/)
      if elements
        hash = {}
        elements.each_index do |i|
          hash[format[i]] = elements[i]
        end
        hash['%Y'] ||= hash['%y'] ? (hash['%y'].to_i + 2000) : Time.now.year
        hash['%H'] ||= 0
        hash['%M'] ||= 0
        hash['%S'] ||= 0
        if hash['%Y'] && hash['%m'] && hash['%d']
          visitor.tz.unadjust(Time.gm(hash['%Y'], hash['%m'], hash['%d'], hash['%H'], hash['%M'], hash['%S']))
        else
          nil
        end
      else
        nil
      end
    end

    def clean_attributes(attrs=params['node'])
      att = secure(Node) { Node.clean_attributes(parse_dates(attrs)) }
    end
    
    def parse_dates(attrs=params['node'])
      # parse dates
      fmt=_('datetime')
      [:v_publish_from, :log_at, :event_at].each do |sym|
        attrs[sym] = parse_date(attrs[sym], fmt) if attrs[sym]
      end
      attrs
    end
    
    # /////// The following methods are common to controllers and views //////////// #
  
    def data_path(node, opts={})
      format = node.kind_of?(Document) ? node.c_ext : nil
      zen_path(node, {:format => format}.merge(opts))
    end
  
    
    # Path for the node (as string). Options can be :format and :mode.
    def zen_path(node, options={})
      return '#' unless node
      if sharp = options.delete(:sharp)
        if sharp =~ /\[(.+)\]/
          sharp_value = node.zafu_read($1)
        else
          sharp_value = "node#{node[:zip]}"
        end
        if sharp_in = options.delete(:sharp_in)
          sharp_node = node.relation(sharp_in) || node
          return "#{zen_path(sharp_node, options)}##{sharp_value}"
        else
          return "##{sharp_value}"          
        end
      end
      
      opts   = options.dup
      format = opts.delete(:format) || 'html'
      pre    = opts.delete(:prefix) || prefix
      mode   = opts.delete(:mode)
      format = 'html' if format.blank?
      
      params = (opts == {}) ? '' : ('?' + opts.map{ |k,v| "#{k}=#{v}"}.join('&'))
      
      if node[:id] == current_site[:root_id] && mode.nil?
        "/#{pre}" # index page
      elsif node[:custom_base]
        "/#{pre}/" +
        node.basepath +
        (mode         ? "_#{mode}" : '') +
        ".#{format}"
      else
        "/#{pre}/" +
        (node.basepath != '' ? "#{node.basepath}/"    : '') +
        (node.vclass.to_s.downcase               ) +
        (node[:zip].to_s                        ) +
        (mode          ? "_#{mode}" : '') +
        ".#{format}"
      end + params
    end
  
    def zen_url(node, opts={})
      path = zen_path(node,opts).split('/').reject { |p| p.blank? }
      prefix = path.shift

      if path == []
        url_for(:prefix=>prefix,              :controller=>'nodes', :action=>'index')
      else
        url_for(:prefix=>prefix, :path=>path, :controller=>'nodes', :action=>'show' )
      end
    end

    def prefix
      if visitor.is_anon?
        if current_site[:monolingual]
          ''
        else
          lang
        end
      else
        AUTHENTICATED_PREFIX
      end
    end
  
    # Restrict access some actions to administrators (used as a before_filter)
    def check_is_admin
      render_404(ActiveRecord::RecordNotFound) unless visitor.is_admin?
      @admin = true
    end
  
    # Notes finder options are
    # [from] node providing the notes. If omitted, <code>@project</code> or <code>@node.project</code> is used.
    # [find] method called on the source. Default is 'notes'. For example, <code>:from=>@node.project, :find=>:notes</code> finds all notes from the project of the current node.
    # [date] only find notes for the given date
    # [using] specify the field used to sort and filter by date. By default, 'log_at' is used
    # [order] sort order. By default "#{using} ASC" is used.
    # []
    def notes(options={})
      source = options[:from] || (@project ||= (@node ? @node.project : nil))
      return [] unless source
    
      options.delete(:from)
      
      method = options[:find] || :notes
      options.delete(:find)
    
      field = options[:using] || :log_at
      options.delete(:using)
    
      options[:order] ||= "#{field} ASC"
      options.delete(:using)
    
      if date = options[:date]
        options.delete(:date)
        options.merge!(:conditions=>["date(#{field}) = ?", date])
      end
    
      source.send(method, options)
    end
  
    #TODO: test
    def error_messages_for(obj_name)
      obj = instance_variable_get("@#{obj_name}")
      return '' unless obj && !obj.errors.empty?
      res = ["<ul>"]
      obj.errors.each do |er,msg|
        res << "<li><b>#{er}</b> #{_(msg)}</li>"
      end
      res << '</ul>'
      res.join("\n")
    end
  
    # TODO: test
    def processing_error(msg)
      # (this method used to be called add_error, but it messed up with 'test/unit/testcase.rb' when testing helpers)
      @errors ||= []
      @errors << trans(msg)
    end
  
    # TODO: test
    def render_errors(errs=@errors)
      if !errs || errs.empty?
        ""
      else
        "<ul><li>#{errs.join("</li>\n<li>")}</li></ul>"
      end
    end
  
    # Find the proper layout to render 'admin' actions. The layout is searched into the visitor's contact's skin first
    # and then into default. This action is also responsible for setting a default @title_for_layout.
    def admin_layout
      @title_for_layout ||= "#{params[:controller]}/#{params[:action]}"
      template_url(:mode=>'admin_layout')
    end
  
    # TODO: test
    def popup_layout
      template_url(:mode=>'popup_layout')
    end
end