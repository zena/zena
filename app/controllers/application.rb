# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  acts_as_secure_controller
  helper_method :prefix, :node_url, :notes, :error_messages_for, :render_errors, :add_error, :data_url
  helper_method :template_text_for_url, :template_url_for_asset, :save_erb_to_url, :lang
  helper 'main'
  before_filter :authorize
  before_filter :set_env
  after_filter  :set_encoding
  layout false
  
  private
  def lang
    visitor.lang
  end
    
  def render_and_cache(opts={})
    @node  ||= secure(Node) { Node.find(ZENA_ENV[:root_id]) }
    opts = {:mode=>opts} if opts.kind_of?(String)
    opts = {:skin=>@node[:skin], :cache=>true}.merge(opts)
      
    @project = @node.project
    @date  ||= params[:date] ? parse_date(params[:date]) : Time.now
    render :template=>template_url(opts), :layout=>false
    
    # only cache the public pages
    if opts[:cache] && visitor.anon?
      cache_page
    end
  end
  
  # TODO: test (adapt for site_id)
  def cache_page(expire_after = nil)
    return unless perform_caching && caching_allowed
    url = url_for(:only_path => true, :skip_relative_url_root => true, :format => params[:format])
    self.class.cache_page(response.body, url)
    path        = self.class.send(:page_cache_file,url)
    puts path
    puts "========================================"
    cache = CachedPage.create(:path => path, :expire_after=>expire_after)
    cache.errors.each do |k,v|
      puts "[#{k}] #{v}"
    end
    values = visitor.visited_node_ids.uniq.map {|id| "(#{cache[:id]}, #{id})"}.join(',')
    CachedPage.connection.execute "INSERT INTO cached_pages_nodes (cached_page_id, node_id) VALUES #{values}"

  end
  
  # Find the best template for the current node's skin, node's class and mode. The template
  # files are searched first into 'app/views/templates/fixed'. If the templates are not found
  # there, they are searched in the database and compiled into 'app/views/templates/compiled'.
  def template_url(opts={})
    skin  = opts[:skin] || (@node ? @node[:skin] : nil) || 'default'
    rescue_template = opts[:rescue_template] || '/templates/fixed/default/any'
    @skin_obj = nil
    skin_helper = nil
    # find best match
    mode  = opts[:mode]
    mode  = nil if (mode.nil? || mode == '')
    klass = @node.class.to_s.downcase
    template = nil
    choices = opts[:choices]
    unless choices
      choices = []
      if skin == 'default'
        #   3. default_class_mode  (101)
        choices << ["default","any_#{klass}_#{mode}"] if mode && klass
        #   4. default__mode       (100)
        choices << ["default","any__#{mode}"] if mode
        #   7. default_class       (  1)
        choices << ["default","any_#{klass}"] if klass
        #   8. default             (  0)
        choices << ["default","any"]
      else
        #                          (mode / template / class)
        #   1. template_class_mode (111)
        choices << [skin,"any_#{klass}_#{mode}"] if mode && klass
        #   2. template__mode      (110)
        choices << [skin,"any__#{mode}"] if mode
        #   3. default_class_mode  (101)
        choices << ["default","any_#{klass}_#{mode}"] if mode && klass
        #   4. default__mode       (100)
        choices << ["default","any__#{mode}"] if mode
        #   5. template_class      ( 11)
        choices << [skin,"any_#{klass}"] if klass
        #   6. template            ( 10)
        choices << [skin,"any"]
        #   7. default_class       (  1)
        choices << ["default","any_#{klass}"] if klass
        #   8. default             (  0)
        choices << ["default","any"]
      end
    end
    if skin
      begin
        @skin_obj = secure(Skin) { Skin.find_by_name(skin) }
        response.template.instance_variable_set(:@session, @session)
        skin_helper = response.template
      rescue ActiveRecord::RecordNotFound
        @skin_obj = nil
      end
    end
    choices.each do |skin, template_name|
      # find the fixed template
      template = "/templates/fixed/#{skin}/#{template_name}"
      break if File.exist?("#{RAILS_ROOT}/app/views#{template}.rhtml")
      # find the compiled version
      template = "/templates/compiled/#{skin}/#{template_name}_#{lang}"
      break if File.exist?("#{RAILS_ROOT}/app/views#{template}.rhtml")
      # search in the @skin_obj
      if @skin_obj
        break if template = @skin_obj.template_url_for_name(template_name, skin_helper)
      end
      # continue search
    end
    return template
  rescue ActiveRecord::RecordNotFound
    # skin name was bad
    return rescue_template
  end
  
  # tested in MainControllerTest
  def template_text_for_url(url)
    url = url[1..-1] # strip leading '/'
    url = url.split('/')
    skin_name = url.shift
    if @skin_obj[:name] == skin_name
      skin = @skin_obj
    end
    skin ||= secure(Skin) { Skin.find_by_name(skin_name) }
    template = skin.template_for_path(url.join('/'))
    template ? template.version.text : nil
  rescue ActiveRecord::RecordNotFound
    return nil
  end

  # TODO: implement
  def template_url_for_asset(type,url)
    # 1. find in current skin ?
    # 2. find in corresponding public directory ?
    case type
    when :stylesheet
    when :link
    when :script
    end
    # 3. find in site ?
  end
  
  # TODO: implement
  def save_erb_to_url(template, template_url)
    "save '#{template_url}':[#{template}]"
  end
  
  def page_not_found
    redirect_to :controller => 'main', :action=>'not_found'
  end
  
  # Verify that only logged in users access to some protected resources. This can be used to remove public access to an
  # entire site. +authorize+ is called before any action in any controller.
  def authorize
    if (ZENA_ENV[:authorize] || params[:prefix] == AUTHENTICATED_PREFIX) && ! session[:user]
      flash[:notice] = trans "Please log in"
      session[:after_login_url] = request.parameters
      redirect_to :controller =>'login', :action=>'login' and return false
    end
  end
  
  # change current language, set @su warning color (tested in MainControllerTest)
  def set_env
    # Set connection charset. MySQL 4.0 doesn't support this so it
    # will throw an error, MySQL 4.1 needs this
    suppress(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute 'SET NAMES UTF8'
    end
    new_lang = nil
    if params[:lang]
      if ZENA_ENV[:languages].include?(params[:lang])
        new_lang = params[:lang]
      else
        new_lang = :bad_language
      end
    elsif params[:prefix] && params[:prefix] != AUTHENTICATED_PREFIX
      if ZENA_ENV[:languages].include?(params[:prefix])
        session[:lang] = params[:prefix]
      else
        new_lang = :bad_language
      end
    end
    
    if new_lang
      if new_lang == :bad_language
        flash[:notice] = trans "The requested language is not available."
        session[:lang] ||= ZENA_ENV[:default_lang]
      else
        session[:lang] = new_lang
      end
      req = request.parameters
      req.delete(:lang)
      req[:prefix] = session[:user] ? AUTHENTICATED_PREFIX : session[:lang]
      redirect_to req and return false
    end
    # If the current user is su, make the CSS ugly so the user does not stay logged in as su.
    if session[:user] == 2
      @su=' style="background:#060;" '
    else
      @su=''
    end
    
    # turn translation on/off
    if params[:translate] 
      if visitor.group_ids.include?(ZENA_ENV[:translate_group])
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
    visitor.lang = session[:lang] ||= (visitor.lang || ZENA_ENV[:default_lang])
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
  
  def parse_dates(hash, fmt=trans('datetime'))
    [:v_publish_from, :log_at, :event_at].each do |sym|
      hash[sym] = parse_date(hash[sym], fmt) if hash[sym] && hash[sym].kind_of?(String)
    end
  end
  
  # /////// The following methods are common to controllers and views //////////// #
  
  def data_url(obj)
    if obj.kind_of?(Document)
      {:controller=>'document', :action=>'data', :version_id=>obj.v_id, :filename=>obj.c_filename, :ext=>obj.c_ext}
    else
      raise StandardError, "Cannot create 'data_url' for #{obj.class}."
    end
  end
  
  def node_url(obj)
    if obj[:id] == ZENA_ENV[:root_id]
      path = []
    else
      path = obj.basepath.split('/')
      unless obj[:custom_base]
        path += ["#{obj.class.to_s.downcase}#{obj[:id]}.html"]
      end
    end
    {:controller => 'main', :action=>'show', :path=>path, :prefix=>prefix}
  end

  def prefix
    if visitor.anon?
      if ZENA_ENV[:monolingual]
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
    return page_not_found unless visitor.is_admin?
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
  def add_error(msg)
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
    rescue_template = '/templates/fixed/default/admin_layout'
    return rescue_template unless visitor && contact = visitor.contact
    
    skin  = contact[:skin] || 'default'
    choices = []

    if skin != 'default'
      choices << [skin,"admin_layout"]
      choices << [skin,"layout"]
    end
    choices << ["default","admin_layout"]
    choices << ["default","layout"]
    return template_url(:skin=>skin, :rescue_template=>rescue_template, :choices=>choices)
  end
  
  # TODO: test
  def popup_layout
    @title_for_layout ||= (@node ? "#{@node.name}: " : "") + "#{params[:controller]}/#{params[:action]}"
    rescue_template = '/templates/fixed/default/popup_layout'
    return rescue_template unless @node
    
    skin  = @node[:skin] || 'default'
    choices = []

    choices << [skin,"popup_layout"] if skin != 'default'

    choices << ["default","popup_layout"]
    choices << ["default","layout"]
    template_url(:skin=>skin, :rescue_template=>rescue_template, :choices=>choices)
  end
end