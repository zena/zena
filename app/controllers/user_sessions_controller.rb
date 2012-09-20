
=begin rdoc
Create, destroy sessions by letting users login and logout. When the user does not login, he/she is considered to be the anonymous user.
=end
class UserSessionsController < ApplicationController
  skip_before_filter :set_after_login, :force_authentication?, :redirect_to_https
  before_filter :session_redirect_to_https

  # /login
  def new
    @node = visitor.site.root_node
    render_and_cache :mode => '+login'
  end

  def create
    User.send(:with_scope, :find => {:conditions => ['site_id = ?', visitor.site.id]}) do
      @user_session = UserSession.new(:login=>params[:login], :password=>params[:password])
      if @user_session.save
        #flash.now[:notice] = _("Successfully logged in.")
        redirect_to  redirect_after_login
      else
        flash[:notice] = _("Invalid login or password.")
        # FIXME: find a better way to lock without blocking the process.
        # Also lock longer and longer (exponentially).
        sleep(2)
        redirect_to login_path
      end
    end
  end

  def destroy
    port = request.port == 80 ? '' : ":#{request.port}"
    if @user_session = UserSession.find
      @user_session.destroy
      reset_session
      #flash.now[:notice] = _("Successfully logged out.")
      redirect_to "http://#{current_site.host}#{params[:redirect] || home_path(:prefix => prefix)}"
    else
      redirect_to "http://#{current_site.host}#{home_path(:prefix => prefix)}"
    end
  end

  private

    # Our own version of set_visitor: always load the anonymous user.
    def set_visitor
      unless site = Site.find_by_host(request.host)
        raise ActiveRecord::RecordNotFound.new("host not found #{request.host}")
      end

      Thread.current[:visitor] = anonymous_visitor(site)
    end

    def redirect_after_login
      session.delete(:after_login_path) || home_path(:prefix => AUTHENTICATED_PREFIX)
    end
    
    # Overwrite redirect on https rules for this controller
    def session_redirect_to_https
      if params[:action] == 'destroy'
        # ignore
      else
        redirect_to :protocol => "https://" if current_site.ssl_on_auth && !ssl_request? && !local_request?
      end
    end
end