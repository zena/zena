# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  acts_as_secure_controller
  helper_method :prefix
  before_filter :authorize
  before_filter :set_env
  layout false
  
  private
  def render_and_cache(opts={})
    opts = {:template=>opts} if opts.kind_of?(String)
    opts = {:template=>nil, :cache=>true}.merge(opts)
    @headers["Content-Type"] = "text/html; charset=utf-8"
    @item  ||= secure(Item) { Item.find(ZENA_ENV[:root_id]) }
    
    if @item && @item.kind_of?(Document) && params[:get] != 'page'
      # send inline data
      data = @item.data
      send_data(data.read, :filename=>@item.name, :type=>data.content_type, :disposition=>'inline')
      cache_page if opts[:cache] && @item.public?
    else
      @project = @item.project
      render "templates/#{template(opts[:template])}"
      
      # only cache the public pages
      if opts[:cache] && !session[:user]
        cache_page
      end
    end
  end
  
  def template(tmplt=nil)
    unless tmplt
      if params[:mode]
        tmplt = params[:mode].gsub('..','').gsub('/','') # security to prevent rendering pages out of 'templates'
      else
        tmplt = @item.template || 'default'
      end
    end
    # try to find a class specific template
    c_tmplt = "#{tmplt}_#{@item.class.to_s.downcase}"
    if File.exist?(File.join(RAILS_ROOT, 'app', 'views', 'main', "#{c_tmplt}.rhtml"))
      c_tmplt
    else
      tmplt
    end
  end
      
  def page_not_found
    redirect_to :controller => 'main', :action=>'not_found'
  end
  
  # Verify that only logged in users access to some protected resources. This can be used to remove public access to an
  # entire site. +authorize+ is called before any action in any controller.
  def authorize
    if (ZENA_ENV[:authorize] == true || params[:prefix] == AUTHENTICATED_PREFIX) && ! session[:user]
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
    if session[:user] && user_id == 2
      @su=' style="background:#600;" '
    else
      @su=''
    end

  end
  
  # "Translate" static text into the current lang
  def trans(keyword, edit=true)
    Trans.translate(keyword).into(lang)
  end
  
  # /////// The following methods are common to controllers and views //////////// #
  
  def prefix
    session && session[:user] ? "#{AUTHENTICATED_PREFIX}" : lang
  end
  
end
=begin
# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  
  
  include ZenaGlobals
  model :item,:address, :user, :group, :page, :tracker, :document, :image, :collector, :project, 
    :note, :contact, :comment, :version, :doc_version, :image_version, :doc_info, :image_info, :link, :image_builder, :form  # (load models) this is used to make find work with sub-classes
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