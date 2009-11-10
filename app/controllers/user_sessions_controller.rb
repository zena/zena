
=begin rdoc
Create, destroy sessions by letting users login and logout. When the user does not login, he/she is considered to be the anonymous user.
=end
class UserSessionsController < ApplicationController

  skip_before_filter :set_after_login

  def new
    @node = visitor.site.root_node
    render_and_cache :mode => '+login'
  end

  def create
    @user_session = UserSession.new(:login=>params[:login], :password=>params[:password])
    user = User.find_by_login(params[:login])
    if @user_session.save
      flash[:notice] = "Successfully logged in."
      redirect_to  Thread.current[:after_login_url] || nodes_path
    else
      flash[:notice] = "Invalid login or password."
      redirect_to login_url
    end
  end

  def destroy
    if @user_session = UserSession.find
      @user_session.destroy
      flash[:notice] = "Successfully logged out."
      redirect_to session[:after_login_url] || nodes_path
    else
      redirect_to session[:after_login_url] || nodes_path
    end
  end

  # skip_before_filter :authorize
  #
  # def new
  #   respond_to do |format|
  #     format.html do
  #       @node = visitor.site.root_node
  #       render_and_cache :mode => 'login'
  #     end
  #   end
  # end
  #
  # def create
  #   if user = User.login(params[:login], params[:password], request.host)
  #     successful_login(user)
  #   else
  #     failed_login _("Invalid login or password.")
  #   end
  # end
  #
  # # Clears session information and redirects to home page.
  # def destroy
  #   reset_session
  #   if request.referer =~ %r{(http://#{visitor.site.host}:\d*/)#{AUTHENTICATED_PREFIX}(.*)}
  #     redirect_to $1  visitor.lang  $2
  #   else
  #     redirect_to :controller => 'nodes', :action => 'index', :prefix => visitor.lang
  #   end
  # end
  #
  # protected
  #
  #   def failed_login(message)
  #     session[:user] = nil
  #     flash[:error] = message
  #     redirect_to '/login'
  #   end
end