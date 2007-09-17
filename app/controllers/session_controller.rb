=begin rdoc
Create, destroy sessions by letting users login and logout. When the user does not login, he/she is considered to be the anonymous user.
=end
class SessionController < ApplicationController
  
  def new
    respond_to do |format|
      format.html do
        @node = visitor.site.root_node
        render_and_cache :mode => '*login'
      end
    end
  end
  
  def create
    if user = User.login(params[:login], params[:password], request.host)
      successful_login(user)
    else
      failed_login _("Invalid login or password.")
    end
  end
  
  # Clears session information and redirects to home page.
  def destroy
    reset_session
    if request.referer =~ %r{(http://#{visitor.site.host}:\d*/)#{AUTHENTICATED_PREFIX}(.*)}
      redirect_to $1 + visitor.lang + $2
    else
      redirect_to :controller=>'nodes', :action=>'index', :prefix=>(visitor.site.monolingual? ? '' : visitor.lang)
    end
  end
  
  protected
    
    def failed_login(message)
      session[:user] = nil
      flash[:error] = message
      redirect_to '/login'
    end
end