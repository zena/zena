# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  helper_method :prefix, :zen_path, :zen_url, :data_path, :node_url, :notes, :error_messages_for, :render_errors, :processing_error
  helper_method :template_text_for_url, :template_url_for_asset, :save_erb_to_url, :lang, :visitor, :fullpath_from_template_url
  helper 'main'
  before_filter :check_env
  before_filter :authorize
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
      return @visitor if @visitor
    
      if session[:user]
        begin
          # we already have a user, check host
          if session[:host] == request.host
            # host hasn't changed, set visitor and site
            @visitor = User.find(session[:user])
            @visitor.site = Site.find(:first, :conditions=>["host = ? ",request.host]) # raises RecordNotFound if site not found
          else
            # changed host
            if site = Site.find(:first, :select=>"sites.*", :from=>"sites, users_sites", :conditions=>["users_sites.site_id = sites.id AND host = ? AND users_sites.user_id = ?",request.host,session[:user]])
              # current user is in the new site
              @visitor = User.find(session[:user])
              @visitor.site = site
            end
          end
        rescue ActiveRecord::RecordNotFound
          # user was not in host or bad session id
          @visitor = nil
        end
      end
    
      unless @visitor
        # find the anonymous visitor for the current site
        if site = Site.find_by_host(request.host)
          @visitor = site.anon
          @visitor.site = site
        else
          # FIXME: error page 505
          raise ActiveRecord::RecordNotFound
          return false
        end
      end
    
      session[:host] = request.host
      session[:user] = @visitor[:id]
      @visitor.visit(@visitor)      # used to check 'su', 'anon', etc
      @visitor.visit(@visitor.site) # used to secure access to 'root_node'
      @visitor
    end
    
    # TODO: test
    def lang
      visitor.lang
    end
    
    def render_and_cache(opts={})
      # cleanup before rendering
      params.delete(:mode)
      params.delete(:format)
    
      opts = {:skin=>@node[:skin], :cache=>true}.merge(opts)
      
      @section = @node.section
      @date  ||= params[:date] ? parse_date(params[:date]) : Time.now
      render :file => template_url(opts), :layout=>false
    
      cache_page if opts[:cache]
    end
  
    # Cache page content into a static file in the current sites directory : SITES_ROOT/test.host/public
    def cache_page(opts={})
      return unless perform_caching && caching_allowed(:authenticated => opts.delete(:authenticated))
      opts = {:expire_after  => nil,
              :path          => (visitor.site.public_path + page_cache_file),
              :content_data  => response.body   
              }.merge(opts)
      secure(CachedPage) { CachedPage.create(opts) }
    end
  
    # Return true if we can cache the current page
    def caching_allowed(opts = {})
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
      mode      = opts[:mode]   || params[:mode]
      format    = opts[:format] || params[:format] || 'html'
      klass     = @node.class
      
      # possible classes for the master template :
      klasses = []
      klass.kpath.split(//).each_index { |i| klasses << klass.kpath[0..i] }
      
      template = secure(Template) { Template.find(:first, 
        :conditions => ["tkpath IN (?) AND format = ? AND mode #{mode ? '=' : 'IS'} ? AND template_contents.node_id = nodes.id", klasses, format, mode],
        :from       => "nodes, template_contents",
        :select     => "nodes.*, template_contents.*, (template_contents.skin_name = #{@skin_name}) AS skin_ok",
        :order      => "length(tkpath) DESC, skin_ok DESC"
      )}
      
      # FIXME use a default fixed template.
      raise ActiveRecord::RecordNotFound unless template
      
      mode = "_#{mode}" if mode
      # FIXME use fullpath instead of 'skin_name'
      skin_root = "#{SITES_ROOT}/#{visitor.site.host}"
      skin_path = "/#{template[:skin_name]}/#{template[:klass]}#{mode}.#{format}"
      main_path = "/#{visitor.lang}/main.erb"
      url = "#{skin_root}/zafu.compiled#{skin_path}#{main_path}"
      
      if File.exists?(url)
        # FIXME: use CachedPage to store the compiled template instead of this File.stat test
        if File.stat(url).mtime < template.v_updated_at
          # template changed, render
          FileUtils.rmtree("#{skin_root}/zafu.compiled#{skin_path}")
          response.template.instance_variable_set(:@session, session)
          skin_helper = response.template
          res = ZafuParser.new_with_url(skin_path, :helper => skin_helper).render
          FileUtils::mkpath(File.dirname(url)) unless File.exists?(File.dirname(url))
          File.open(url, "wb") { |f| f.syswrite(res) }
        end
      end
    
      return url
    end
  
    # Return a template's content from an url. If the url does not start with a '/', we try by replacing the
    # first element with the current skin_name and if it does not work, we try with the full url. If the url
    # start with a '/' we use the full url directly.
    # tested in MainControllerTest
    def template_text_for_url(url)
      @skin ||= {}
      if url =~ /^\//
        url = url[1..-1].split('/')
        skin_names = [url.shift]
      else
        url = url.split('/')
        skin_names = [@skin_name, url.shift]
      end
      
      partial = nil
      skin_names.each do |skin_name|
        skin = @skin[skin_name] ||= secure(Skin) { Skin.find_by_name(skin_name) }
        path = (skin.fullpath.split('/') + url).join('/')
        break if partial = secure(TextDocument) { TextDocument.find_by_path(path) }
      end
      partial ? partial.version.text : nil
    end

    # TODO: implement
    def template_url_for_asset(opts)
    
      # 1. find in current skin ?
      url = opts[:current_template][1..-1].split('/') + opts[:src].split('/')
      url.compact!
      skin_name = url.shift
      if @skin_obj && @skin_obj[:name] == skin_name
        skin = @skin_obj
      end
      skin ||= secure(Skin) { Skin.find_by_name(skin_name) }
      asset = skin.asset_for_path(url.join('/'), Document)
      asset ? node_url(asset) : nil
    rescue ActiveRecord::RecordNotFound
      return nil
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
      path = "/#{template_url[0]}/#{template_url[1]}/#{visitor.lang}/#{template_url[2..-1].join('/')}"

      if template_url[0] == 'default'
        "#{SITES_ROOT}/shared/zafu.compiled#{path}"
      else
        "#{SITES_ROOT}/#{visitor.site.host}/zafu.compiled#{path}"
      end
    end
  
    # Verify that only logged in users access to some protected resources. This can be used to remove public access to an
    # entire site. +authorize+ is called before any action in any controller.
    def authorize
      if (visitor.site[:authorize] || params[:prefix] == AUTHENTICATED_PREFIX) && ! session[:user]
        flash[:notice] = trans "Please log in"
        session[:after_login_url] = request.parameters
        redirect_to :controller =>'login', :action=>'login' and return false
      end
    end
  
    # Make sure everything is in sync, change current language, set @su warning color (tested in MainControllerTest)
    def check_env
      # Set connection charset. MySQL 4.0 doesn't support this so it
      # will throw an error, MySQL 4.1 needs this
      suppress(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.connection.execute 'SET NAMES UTF8'
      end
    
      redirect_to not_found_path if params[:id] && params[:path] # make sure we do not mix 'pretty urls' with resources.
    
      new_lang = nil
      if params[:lang]
        if visitor.site.lang_list.include?(params[:lang])
          new_lang = params[:lang]
        else
          new_lang = :bad_language
        end
      elsif params[:prefix] && params[:prefix] != AUTHENTICATED_PREFIX
        if visitor.site.lang_list.include?(params[:prefix])
          session[:lang] = params[:prefix]
        else
          new_lang = :bad_language
        end
      end
    
      if new_lang
        if new_lang == :bad_language
          flash[:notice] = trans "The requested language is not available."
          session[:lang] ||= visitor.site[:default_lang]
        else
          session[:lang] = new_lang
        end
        req = request.parameters
        req.delete(:lang)
        req[:prefix] = visitor.is_anon? ? session[:lang] : AUTHENTICATED_PREFIX
        redirect_to req and return false
      end
      # If the current user is su, make the CSS ugly so the user does not stay logged in as su.
      if visitor.is_su?
        @su=' style="background:#060;" '
      else
        @su=''
      end
    
      # turn translation on/off
      if params[:translate] 
        if visitor.group_ids.include?(visitor.site[:trans_group_id])
          if params[:translate] == 'on'
            session[:translate] = true
          else
            session[:translate] = nil
          end
        end
        req = request.parameters
        req.delete(:translate)
        redirect_to req and return false  
      end
      visitor.lang = session[:lang] ||= (visitor.lang || visitor.site[:default_lang])
      
      true
    end
    
    # translate 'fake' ids into real ones
    def cleanup_node_params(attrs=params['node'])
      res = attrs.dup
      
      parent_id = res.delete('parent_id')
      if parent_id && parent_id.to_i.to_s != parent_id.strip
        # find by name
        parent_id = secure(Node) { Node.find_by_name(parent_id) }[:id]
      elsif parent_id
        # pass it to the 'zip translator below'
        res['parent_id'] = parent_id
        parent_id = nil
      end
      
      res.keys.each do |key|
        if key =~ /^(\w+)_id$/
          res[key] = Node.connection.execute( "SELECT id FROM nodes WHERE site_id = #{visitor.site[:id]} AND zip = '#{attrs[key].to_i}'" ).fetch_row[0]
        end
      end
      
      res['parent_id'] = parent_id if parent_id
      
      res.delete('file') if res['file'] == ''
          
      # parse dates
      fmt=trans('datetime')
      [:v_publish_from, :log_at, :event_at].each do |sym|
        res[sym] = parse_date(res[sym], fmt) if res[sym]
      end
      res
    end
    
  
    # "Translate" static text into the current lang
    def trans(keyword, edit=true)
      TransPhrase[keyword][lang]
    end
  
    def set_encoding
      headers['Content-Type'] ||= 'text/html'
      if headers['Content-Type'].starts_with?('text/') and !headers['Content-Type'].include?('charset=')
        headers['Content-Type'] += '; charset=utf-8'
      end
    end
  
    # Parse date : return a date from a string
    # TODO: test time_zone..
    def parse_date(datestr, fmt=trans('datetime'))
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
    
    def create_node(attrs=params['node'])
      klass = attrs.delete(:klass) || 'Page'
      attrs = cleanup_node_params(attrs)
      
      klass = Module::const_get(klass.capitalize.to_sym)
      raise NameError unless klass.ancestors.include?(Node)
      node = secure(klass) { klass.create(attrs) }
    rescue NameError => err
      node = secure(Node) { Node.new }
      node.attributes = attrs
      node.errors.add('klass', 'invalid')
      # This is to show the klass in the form seizure
      node.instance_variable_set(:@klass, klass)
      def node.klass; @klass; end
      node
    end
  
    # /////// The following methods are common to controllers and views //////////// #
  
    def data_path(obj)
      zen_path(obj, :format => obj.c_ext)
    end
  
    # Path for the node (as string). Options can be :format and :mode.
    def zen_path(obj, opts={})
      opts = {:format => params[:format], :prefix => prefix}.merge(opts)
      opts[:format] = 'html' if opts[:format].nil? || opts[:format] == ''
      if obj[:id] == visitor.site[:root_id] && opts[:mode].nil?
        "/#{opts[:prefix]}" # index page
      elsif obj[:custom_base]
        "/#{opts[:prefix]}/" +
        obj.basepath +
        (opts[:mode]    ? "_#{opts[:mode]}" : '') +
        ".#{opts[:format]}"
      else
        "/#{opts[:prefix]}/" +
        (obj.basepath != '' ? "#{obj.basepath}/"    : '') +
        (obj.class.to_s.downcase               ) +
        (obj[:zip].to_s                        ) +
        (opts[:mode]    ? "_#{opts[:mode]}" : '') +
        ".#{opts[:format]}"
      end
    end
  
    def zen_url(obj, opts={})
      path = zen_path(obj,opts).split('/').reject { |p| p.nil? || p == ''}
      prefix = path.shift

      if path == []
        url_for(:prefix=>prefix,              :controller=>'nodes', :action=>'index')
      else
        url_for(:prefix=>prefix, :path=>path, :controller=>'nodes', :action=>'show' )
      end
    end

    def prefix
      if visitor.is_anon?
        if visitor.site[:monolingual]
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
        res << "<li><b>#{er}</b> #{trans(msg)}</li>"
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