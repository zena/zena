=begin rdoc
Create, destroy sessions by letting users login and logout. When the user does not login, he/she is considered to be the anonymous user.
=end
class SessionController < ApplicationController
  
  def create
    if user = User.login(params[:login], params[:password], visitor.site)
      successful_login(user)
    else
      failed_login trans("Invalid login or password.")
    end
  end
  
  # Clears session information and redirects to login page.
  def destroy
    reset_session
    redirect_to :controller=>'nodes', :action=>'index', :prefix=>(visitor.site.monolingual? ? '' : visitor.lang)
  end
  
  protected
    def successful_login(user)
      session[:user] = user[:id]
      visitor = user
      visitor.visit(visitor)
      # reset session lang, will be set from user on next request
      session[:lang] = nil
      # TODO: test after_login_url
      after_login_path = session[:after_login_url] || user_home_path
      session[:after_login_url] = nil
      redirect_to after_login_path
    end
    
    def failed_login(message)
      flash.now[:error] = message
      render :action => 'new'
    end
end