
=begin rdoc
Create, destroy sessions by letting users login and logout. When the user does not login, he/she is considered to be the anonymous user.
=end
class UserSessionsController < ApplicationController
  skip_before_filter :set_after_login, :force_authentication?

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
        redirect_to login_url
      end
    end
  end

  def destroy
    if @user_session = UserSession.find
      @user_session.destroy
      reset_session
      #flash.now[:notice] = _("Successfully logged out.")
      redirect_to params[:redirect] || home_path(:prefix => prefix)
    else
      redirect_to home_path(:prefix => prefix)
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
      session.delete(:after_login_url) || home_path(:prefix => AUTHENTICATED_PREFIX)
    end

end