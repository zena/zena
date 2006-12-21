class UserController < ApplicationController
  helper MainHelper
  # This view contains all the relevant information for a user's home in the CMS. From here, the
  # user can view the versions his is currently editing, he can publish content, etc
  def home
    @user = User.find(session[:user][:id])
    render :layout=>'admin'
  end
end
