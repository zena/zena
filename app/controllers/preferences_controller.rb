class PreferencesController < ApplicationController
  before_filter :check_user
  layout :admin_layout
  
  # TODO: test
  def list
    @user = visitor
  end
  
  # TODO: test
  def change_password
    @user = User.find(visitor[:id]) # reload to get password
    if params[:user][:password].strip.size < 6
      @user.errors.add('password', 'too short')
    end
    if params[:user][:password] != params[:user][:retype_password]
      @user.errors.add('retype_password', 'does not match new password')
    end
    if User.hash_password(params[:user][:old_password]) != @user[:password]
      @user.errors.add('old_passowrd', 'not correct')
    end
    if @user.errors.empty?
      @user.password = params[:user][:password]
      if @user.save
        flash[:notice] = trans 'password successfully updated'
      end
    end
  end
  
  #TODO: test
  def change_info
    @user = User.find(visitor[:id]) # reload to get password
    # only accept changes on the following fields through this interface
    params.delete(:lang) unless ZENA_ENV[:languages].include?(params[:lang])
    [:login, :first_name, :name, :time_zone, :lang, :email].each do |sym|
      @user[sym] = params[:user][sym]
    end
    
    if @user.save
      flash[:notice] = trans 'information successfully updated'
      session[:lang] = params[:user][:lang] if params[:user][:lang]
    end
  end
  
  private
  # TODO: test
  def check_user
    if visitor[:id] == 1
      page_not_found
    end
  end
end
