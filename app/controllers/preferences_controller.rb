class PreferencesController < ApplicationController
  before_filter :check_user
  helper MainHelper
  layout 'admin'
  
  # TODO: test
  def list
  end
  
  # TODO: test
  def change_password
    if User.hash_password(params[:user][:old_password]) != @user[:password]
      add_error 'old password not correct'
    end
    if params[:user][:password] != params[:user][:retype_password]
      add_error 'control password and password do not match'
    end
    if params[:user][:password].strip.size < 6
      add_error 'password too short'
    end
    unless @errors
      @user.password = params[:user][:password]
      if @user.save
        flash[:notice] = trans 'password successfully updated'
      end
    end
  end
  
  #TODO: test
  def change_info
    # only accept changes on the following fields through this interface
    [:login, :first_name, :name, :timezone, :email].each do |sym|
      @user[sym] = params[:user][sym]
    end
    if @user.save
      flash[:notice] = trans 'information successfully updated'
    end
  end
  
  private
  # TODO: test
  def check_user
    if session[:user]
      @user = User.find(session[:user][:id])
    else
      page_not_found
    end
  end
end
