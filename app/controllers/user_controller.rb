class UserController < ApplicationController
  before_filter :check_is_admin, :except=>[:home]
  helper MainHelper
  layout 'admin'
  # This view contains all the relevant information for a user's home in the CMS. From here, the
  # user can view the versions his is currently editing, he can publish content, etc
  def home
    @user = User.find(session[:user][:id])
  end
  
  # TODO: test
  def list
    @user_pages, @users =
            paginate :users, :order => 'name, first_name', :per_page => 20
    @groups = Group.find(:all, :order=>'name')
  end
  
  # TODO: test
  def create
    if params[:groups]
      params[:user][:group_ids] = params[:group].values
    end
    puts params.inspect
    User.create(params[:user])
    redirect_to :action=>'list'
  end
  
  # TODO: test
  def edit
    render :nothing=>true if 1 == params[:id]
    @user = User.find(params[:id])
    @user.password = nil
    @groups = Group.find(:all, :order=>'name')
    render :partial=>'user/form'
  end
  
  # TODO: test
  def update
    if params[:groups]
      params[:user][:group_ids] = params[:groups].values
      params[:user][:group_ids] << 1 unless params[:user][:group_ids].include?(1)
    end
    @user = User.find(params[:user][:id])
    @user.update_attributes(params[:user])
    @user.save
    redirect_to :action=>'list'
  end
end
