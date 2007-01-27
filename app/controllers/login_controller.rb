class LoginController < ApplicationController
  before_filter :authorize, :except => [:login, :logout]
  
  def login
    if request.get?
      # empty session
    else
      # request with completed form
      logged_in_user = User.login(params[:user][:login], params[:user][:password])
      params[:user][:password] = ""
      if logged_in_user
        session[:user] = logged_in_user[:id]
        # reset session lang, will be set from user on next request
        session[:lang] = nil
        redirect_to user_home_url
      else
        flash[:error] = "Invalid login or password"
      end
    end
  end
  
  # Clears session information and redirects to login page.
  def logout
    reset_session
    redirect_to :action=>'login'
  end
  
  # tested to here
end
