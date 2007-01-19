# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  acts_as_secure_controller
  helper_method :prefix, :notes, :visitor_is_admin?, :error_messages_for, :render_errors, :add_error
  before_filter :authorize
  before_filter :set_env
  after_filter  :set_encoding
  layout false
  
  private
  def render_and_cache(opts={})
    opts = {:template=>opts} if opts.kind_of?(String)
    opts = {:template=>nil, :cache=>true}.merge(opts)
    @node  ||= secure(Node) { Node.find(ZENA_ENV[:root_id]) }
      
    @project = @node.project
    render :template=>"templates/#{template(opts[:template])}", :layout=>false
    
    # only cache the public pages
    if opts[:cache] && !session[:user]
      cache_page
    end
  end
  
  def template(tmplt=nil)
    unless tmplt
      if params[:mode]
        tmplt = params[:mode].gsub('..','').gsub('/','') # security to prevent rendering pages out of 'templates'
      else
        tmplt = @node.template || 'default'
      end
    end
    
    # try to find a class specific template, starting with the most specialized, then the class specific and finally
    # the contextual template or default
    ["#{tmplt}_#{@node.class.to_s.downcase}", "any_#{@node.class.to_s.downcase}", tmplt ].each do |filename|
      if File.exist?(File.join(RAILS_ROOT, 'app', 'views', 'templates', "#{filename}.rhtml"))
        return filename
      end
    end
    return 'default'
  end
  
  def render_form
    render :template=>"templates/#{form_template}"
  end
  
  def form_template
    tmplt = @node.template || 'default'
    # try to find a class specific template, starting with the most specialized, then the class specific and finally
    # the contextual template or default
    ["#{tmplt}_#{@node.class.to_s.downcase}", "any_#{@node.class.to_s.downcase}", tmplt ].each do |filename|
      if File.exist?(File.join(RAILS_ROOT, 'app', 'views', 'templates', 'forms', "#{filename}.rhtml"))
        return "forms/#{filename}"
      end
    end
    return 'forms/default'
  end
   
  def page_not_found
    redirect_to :controller => 'main', :action=>'not_found'
  end
  
  # Verify that only logged in users access to some protected resources. This can be used to remove public access to an
  # entire site. +authorize+ is called before any action in any controller.
  def authorize
    if (ZENA_ENV[:authorize] || params[:prefix] == AUTHENTICATED_PREFIX) && ! session[:user]
      flash[:notice] = trans "Please log in"
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
    if session[:user] && visitor_id == 2
      @su=' style="background:#060;" '
    else
      @su=''
    end
    
    # turn translation on/off
    if params[:translate] 
      if visitor_groups.include?(ZENA_ENV[:translate_group])
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
        Time.gm(hash['%Y'], hash['%m'], hash['%d'], hash['%H'], hash['%M'], hash['%S'])
      else
        nil
      end
    else
      nil
    end
  end
  
  def parse_dates(obj, fmt=trans('datetime'))
    [:publish_from, :log_at, :event_at].each do |sym|
      obj[sym] = parse_date(obj[sym], fmt) if obj[sym] && obj[sym].kind_of?(String)
    end
  end
  
  # /////// The following methods are common to controllers and views //////////// #
  
  def prefix
    (session && session[:user]) ? AUTHENTICATED_PREFIX : lang
  end
  
  # TODO: test
  def visitor_is_admin?
    (visitor_groups.include?(2) || visitor_id == 2)
  end
  
  # TODO: test
  def check_is_admin
    page_not_found unless visitor_is_admin?
    @admin = true
  end
  
  # Notes finder options are
  # [from] node providing the notes. If omitted, <code>@project</code> or <code>@node.project</code> is used.
  # [find] method called on the source. Default is 'notes'. For example, <code>:from=>@node.project, :find=>:news</code> finds all news from the project of the current node.
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
  def error_messages_for(obj)
    # FIXME: SECURITY is there a better way to do this ?
    obj = eval("@#{obj}")
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
      "<ul class='error'><li>#{errs.join("</li>\n</li>")}</li></ul>"
    end
  end
end
=begin
# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  
  
  include ZenaGlobals
  model :node,:contact, :user, :group, :page, :tracker, :document, :image, :collector, :project, 
    :note, :contact, :comment, :version, :doc_version, :image_version, :doc_file, :image_file, :link, :image_builder, :form  # (load models) this is used to make find work with sub-classes
  before_filter :set_env
  layout 'default'
  

  
end

# Save content to fixtures: this should be removed for security reasons before going to production. TODO.
class ActiveRecord::Base
  # code adapted from by http://www.pylonhead.com/code/yaml.html
  def self.to_fixtures
    str= self.find(:all).inject("") { |s, record|
        self.columns.inject(s+"#{record.id}:\n") { |s, c|
          s+"  #{{c.name => record.attributes[c.name]}.to_yaml[5..-1]}\n" }
    }
    filename = File.expand_path("test/fixtures/#{table_name}.yml", RAILS_ROOT)
    f = File.new(filename, "w")
    f.puts str
    f.close
    [filename, str]
  end
end
=end