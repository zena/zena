require 'gettext/rails'

class ApplicationController < ActionController::Base
  init_gettext 'zena'
  helper_method :prefix, :zen_path, :zen_url, :data_path, :node_url, :notes, :error_messages_for, :render_errors, :processing_error
  helper_method :get_template_text, :template_url_for_asset, :save_erb_to_url, :lang, :visitor, :fullpath_from_template_url, :eval_parameters_from_template_url
  before_filter :set_lang
  before_filter :authorize
  before_filter :check_lang
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
        end
        if user.is_anon?
          user.ip = request.headers['REMOTE_ADDR']
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
      opts[:format] ||= params[:format] || 'html'
      
      # cleanup before rendering
      params.delete(:mode)
      params.delete(:format)
      
      @section = @node.section
      # init default date used for calendars, etc
      @date  ||= params[:date] ? parse_date(params[:date]) : Date.today
      
      begin
        if opts[:format] != 'html'
          content_type = (EXT_TO_TYPE[opts[:format]] || ['application/octet-stream'])[0]
          data = render_to_string(:file => template_url(opts), :layout=>false)
          send_data( data , :filename=>@node.v_title, :type => content_type, :disposition=>'inline')
          cache_page(:content_data => data) if opts[:cache]
        else
          render :file => template_url(opts), :layout=>false
          cache_page if opts[:cache]
        end
      rescue ActiveRecord::RecordNotFound
        redirect_to zen_path(@node)
      end
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
      ext = params[:format] || 'html'
      path << ".#{ext}" unless path =~ /\.#{ext}$/
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
      
      lang_path = session[:dev] ? "dev_#{lang}" : lang
      
      skin_path = "/#{template[:skin_name]}/#{template[:name]}"  
      fullpath  = skin_path + "/#{lang_path}/_main.erb"
      url       = SITES_ROOT + current_site.zafu_path + fullpath

      if !File.exists?(url) || params[:rebuild]
        # no template ---> render
        # clear :
        FileUtils::rmtree(File.dirname(url))
        
        # set the places to search for the included templates
        # FIXME: there might be a better way to do this. In a hurry, fix later.
        @skin       = {}
        @skin_names = [@skin_name]
        secure(Skin) { Skin.find(:all, :order=>'position ASC, name ASC') }.each do |s|
          @skin[s.name] = s
          @skin_names << s.name
        end
        @skin_names.uniq!
        @skin_link  = zen_path(@skin[@skin_name]) # used to link from <r:design/> zafu tag
        @expire_with_nodes = {}
        @renamed_assets    = {}
        
        response.template.instance_variable_set(:@session, session)
        skin_helper = response.template
        # [1..-1] = drop leading '/' so find_template_document searches in the current skin first
        res = ZafuParser.new_with_url(skin_path[1..-1], :helper => skin_helper).render
        
        if session[:dev] && mode != '*popupLayout'
          # add template edit buttons
          used_nodes = @expire_with_nodes.merge(@renamed_assets)
          div = "<div id='dev'><ul>" + used_nodes.map do |k,n| "<li>#{skin_helper.send(:node_actions, :node=>n)} #{skin_helper.send(:link_to,k,zen_path(n))}</li>"
          end.join("") +
          "<li><span class='actions'><a href='?rebuild=true'>#{_('rebuild')}</a></li>" +
          "<li><span class='actions'><a href='/users/#{visitor[:id]}/swap_dev'>#{_('turn dev off')}</a></span></li>" +
          "<li>(#{@skin_names.join(', ')})</li>"
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

    def template_url_for_asset(opts)
      return nil unless res = find_template_document(opts)
      asset, url = *res
      @renamed_assets[url] = asset
      data_path(asset)
    rescue ActiveRecord::RecordNotFound
      return nil
    end
    
    # opts should contain :current_template and :src. The source is a path like 'default/Node-*index'
    # ('skin/template/path'). If the path starts with a slash, the skin_name in the path is searched first. Otherwise,
    # the current skin is searched first.
    def find_template_document(opts)
      src    = opts[:src]
      if src =~ /\A(.*)\.(\w+)\Z/
        src, format = $1, $2
      end
      folder = (opts[:current_folder] && opts[:current_folder] != '') ? opts[:current_folder].split('/') : []
      @skin ||= {}
      
      if src =~ /^\//
        # starts with '/' : look here first
        url = src[1..-1].split('/')
        skin_names = [url.shift] + @skin_names
      else
        # does not start with '/' : look in skin_names first
        url = folder + src.split('/')
        skin_names = @skin_names.dup
        skin_names << url.shift if url.size > 1
      end
      document = skin_name = nil
      skin_names.uniq!
      [false, true].each do |rebuild_path|
        # try to find using cached fullpath first.
        skin_names.each do |skin_name|
          next unless skin = @skin[skin_name] ||= (secure(Skin) { Skin.find_by_name(skin_name) } rescue nil)
          path = (skin.fullpath(rebuild_path).split('/') + url).join('/')
          break if document = secure(TextDocument) { TextDocument.find_by_path(path) } rescue nil
        end
        break if document
      end
      return document ? [document, (([skin_name] + url).join('/') + (format ? ".#{format}" : ''))] : nil
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
      if template_url =~ /\A\.|[^\w\*\._\-\/]/
        raise Zena::AccessViolation.new("'template_url' contains illegal characters : #{template_url.inspect}")
      end
      
      template_url = template_url[1..-1].split('/')
      path = "/#{template_url[0]}/#{template_url[1]}/#{session[:dev] ? "dev_#{lang}" : lang}/#{template_url[2..-1].join('/')}"

      "#{SITES_ROOT}/#{current_site.host}/zafu#{path}"
    end
    
    def eval_parameters_from_template_url(template_url=params[:template_url])
      return {} unless template_url
      path = fullpath_from_template_url(template_url) + '.erb'
      if File.exists?(path)
        eval File.read(path)
      else
        nil
      end
    end
    # Require a login for authenticated navigation (with '/oo' prefix) or for any content if the site's 'authorize'
    # attribute is true.
    def authorize
      return true if params[:controller] == 'session' && ['create', 'new', 'destroy'].include?(params[:action])
      
      # Require a login if :
      # 1. site forces authentication or navigation in '/oo'
      if (current_site.authentication? || params[:prefix] == AUTHENTICATED_PREFIX) && visitor.is_anon?
        return false unless do_login
      end
      
      # Redirect if :
      # 1. navigating out of '/oo' but logged in and format is not data
      if (params[:prefix] && params[:prefix] != AUTHENTICATED_PREFIX && !visitor.is_anon?)
        return true unless format_changes_lang
        redirect_to request.parameters.merge(:prefix=>AUTHENTICATED_PREFIX) and return false
      end
    end
    
    # Return true if the current request can change the current language. Document data do not
    # change lang.
    def format_changes_lang
      format = params[:format] || (params[:path] || [''])[-1].split('.').last
      ['xml','html', nil].include?(format)
    end
    
    def do_login
      if current_site[:http_auth]
        session[:after_login_url] = request.parameters
        basic_auth_required do |username, password| 
          if user = User.make_visitor(:login => username, :password => password, :site => current_site)
            successful_login(user)
            return true
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
      session[:lang] = user.lang
      
      @visitor = user
      @visitor.visit(@visitor)
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
    # 2. 'test.host/fr' this rule is called once we are sure the request is not for document data (lang in this case can be different from what the visitor is visiting due to caching optimization)
    # 3. 'test.host/oo' use visitor[:lang]
    # 4. 'test.host/'   use session[:lang]
    # 5. 'test.host/oo' use visitor lang
    # 6. 'test.host/'   use HTTP_ACCEPT_LANGUAGE
    # 7. 'test.host/'   use default language
    def set_lang
      [
        params[:lang],
        format_changes_lang ? params[:prefix] : nil, # only if index (/fr, /en) or ending with 'html'
        visitor.is_anon? ? session[:lang] : visitor.lang,
        (request.headers['HTTP_ACCEPT_LANGUAGE'] || '').split(',').sort {|a,b| (b.split(';q=')[1] || 1.0).to_f <=> (a.split(';q=')[1] || 1.0).to_f }.map {|l| l.split(';')[0].split('-')[0] },
        (visitor.is_anon? ? visitor.lang : nil), # anonymous user's lang comes last
      ].compact.flatten.uniq.each do |l|
        if current_site.lang_list.include?(l)
          session[:lang] = l
          break
        end
      end
      
      session[:lang] ||= current_site[:default_lang]
      
      if visitor.lang != session[:lang] && !visitor.is_anon?
        visitor.update_attribute_with_validation_skipping('lang', session[:lang])
      else
        visitor.lang = session[:lang]
      end
      GetText.set_locale_all(session[:lang])
      true
    end
    
    # Redirect on lang chang
    def check_lang
      if params[:lang]
        # redirects other controllers (users controller, etc)
        redirect_url = params
        redirect_url.delete(:lang)
        if params[:controller] == 'nodes'
          redirect_to redirect_url.merge(:prefix => prefix) and return false
        else
          redirect_to redirect_url and return false
        end
      end
      true
    end
  
    def set_encoding
      headers['Content-Type'] ||= 'text/html'
      if headers['Content-Type'].starts_with?('text/') and !headers['Content-Type'].include?('charset=')
        headers['Content-Type'] += '; charset=utf-8'
      end
    end
    
    # /////// The following methods are common to controllers and views //////////// #
  
    # Return the path to a document's data
    def data_path(node, opts={})
      return zen_path(node,opts) unless node.kind_of?(Document)
      if node.public? && !current_site.authentication?
        # force the use of a cacheable path for the data, even when navigating in '/oo'
        # FIXME: we could use 'node.version.lang' if most of the time the version is loaded.
        zen_path(node, opts.merge(:format => node.c_ext, :prefix=>(current_site[:monolingual] ? '' : node.v_lang)))
      else  
        zen_path(node, opts.merge(:format => node.c_ext))
      end
    end
  
    
    # Path for the node (as string). Options can be :format and :mode.
    def zen_path(node, options={})
      return '#' unless node
      if sharp = options.delete(:sharp)
        if sharp =~ /\[(.+)\]/
          sharp_value = node.zafu_read($1)
        elsif sharp == 'true'
          sharp_value = "node#{node[:zip]}"
        else
          sharp_value = sharp
        end
        if sharp_in = options.delete(:sharp_in)
          sharp_node = node.find(:first, :relations=>[sharp_in]) || node
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
  
    #TODO: test
    def error_messages_for(obj, opts={})
      return '' if obj.errors.empty?
      res = ["<ul class='#{opts[:class] || 'errors'}'>"]
      obj.errors.each do |er,msg|
        res << "<li><b>#{er}</b> #{_(msg)}</li>"
      end
      res << '</ul>'
      res.join("\n")
    end
  
    # TODO: test (where is this used ? discussions, ?)
    def processing_error(msg)
      # (this method used to be called add_error, but it messed up with 'test/unit/testcase.rb' when testing helpers)
      @errors ||= []
      @errors << _(msg)
    end
  
    # TODO: test
    def render_errors(errs=@errors)
      if !errs || errs.empty?
        ""
      elsif errs.kind_of?(ActiveRecord::Errors)
        res = "<ul class='errors'>"
        errs.each do |k,v|
          res << "<li><b>#{k}</b> #{v}</li>\n"
        end
        res << "</ul>"
        res
      else
        "<ul class='errors'><li>#{errs.join("</li>\n<li>")}</li></ul>"
      end
    end
  
    # Find the proper layout to render 'admin' actions. The layout is searched into the visitor's contact's skin first
    # and then into default. This action is also responsible for setting a default @title_for_layout.
    def admin_layout
      @title_for_layout ||= "#{params[:controller]}/#{params[:action]}"
      template_url(:mode=>'*adminLayout')
    end
  
    # TODO: test
    def popup_layout
      template_url(:mode=>'*popupLayout')
    end
end
