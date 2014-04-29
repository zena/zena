
=begin rdoc
Create, destroy sessions by letting users login and logout. When the user does not login, he/she is considered to be the anonymous user.
=end
class UserSessionsController < ApplicationController
  skip_before_filter :force_authentication?, :redirect_to_https
  before_filter :session_redirect_to_https

  # /login
  def new
    # If user is already logged in, redirect to home page
    if !visitor.is_anon?
      redirect_to home_path(:prefix => prefix)
    else
      @node = visitor.site.root_node
      render_and_cache :mode => '+login'
    end
  end

  def create
    User.send(:with_scope, :find => {:conditions => ['site_id = ?', visitor.site.id]}) do
      if user = User.find_by_login(params[:login])
        # FAIL: 1s, FAIL: 2s, FAIL: 4s, FAIL: 8s, FAIL: 16s, FAIL: 32s, FAIL: 64s
        wait_in_seconds = 2 ** user.login_attempt_count.to_i
        elapsed         = Time.now.to_i - user.login_attempted_at.to_i
        if elapsed < wait_in_seconds
          w = Time.at(wait_in_seconds - elapsed)
          msg = _("You need to wait %ih %im %is before any new attempt (%i failed attempts).")
          flash[:error] = msg % [w.hour, w.min, w.sec, user.login_attempt_count.to_i]
          return redirect_to login_path
        end
      else
        flash[:error] = _("Invalid login or password.")
        return redirect_to login_path
      end
      @user_session = UserSession.new(:login=>params[:login], :password=>params[:password])
      if @user_session.save
        # Reset login attempts count
        Zena::Db.set_attribute(user, 'login_attempt_count', 0)
        Zena::Db.set_attribute(user, 'login_attempted_at',  nil)
        redirect_to  redirect_after_login
      else
        flash[:error] = _("Invalid login or password.")
        Zena::Db.set_attribute(user, 'login_attempt_count', user.login_attempt_count.to_i + 1)
        Zena::Db.set_attribute(user, 'login_attempted_at',  Time.now.utc)
        redirect_to login_path
      end
    end
  end

  # Logout
  def destroy
    port = request.port == 80 ? '' : ":#{request.port}"
    if @user_session = UserSession.find
      @user_session.destroy
      reset_session
      if current_site.ssl_on_auth
        # SSH only when authenticated
        host = current_site.host
        http = 'http'
      else
        # Keep current host and port settings
        host = host_with_port
        http = host =~ /:443/ ? 'https' : 'http'
      end
      #flash.now[:notice] = _("Successfully logged out.")
      redirect_to "#{http}://#{host}#{params[:redirect] || home_path(:prefix => prefix)}"
    else
      redirect_to "http://#{host}#{home_path(:prefix => prefix)}"
    end
  end

  private

    # Our own version of set_visitor: always load the anonymous user.
    def set_visitor
      unless site = Site.find_by_host(request.host)
        raise ActiveRecord::RecordNotFound.new("host not found #{request.host}")
      end
      
      if params[:action] == 'new'
        # keep visitor
        super
      else
        setup_visitor(anonymous_visitor(site), site)
      end
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