class LoginController < ApplicationController
  before_filter :authorize, :except => [:login, :logout]
  
  def login
    if request.get?
      # empty request
      set_session_with_user( nil )
      @user = User.new
    else
      # request with completed form
      logged_in_user = User.login(params[:user][:login], params[:user][:password])
      params[:user][:password] = ""
      if logged_in_user
        set_session_with_user logged_in_user
        redirect_to user_home_url
      else
        flash[:error] = "Invalid user/password combination"
      end
    end
  end
  
  # Clears session information and redirects to login page.
  def logout
    set_session_with_user( nil )
    redirect_to :action=>'login'
  end
  
  # tested to here
end
