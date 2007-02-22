class UserController < ApplicationController
  before_filter :check_is_admin, :except=>[:home, :preferences, :change_password]
  layout 'admin'
  # This view contains all the relevant information for a user's home in the CMS. From here, the
  # user can view the versions his is currently editing, he can publish content, etc
  def home
    @user = User.find(session[:user])
  end
  
  # TODO: test
  def show
    @user = User.find(params[:id])
  end
  
  # TODO: test
  def list
    @user_pages, @users =
            paginate :users, :order => 'id', :per_page => 20
    @groups = Group.find(:all, :order=>'id')
    @user = User.new
  end
  
  # TODO: test
  def create
    if params[:groups]
      params[:user][:group_ids] = params[:groups].values
    end
    @groups = Group.find(:all, :order=>'id')
    @user = User.create(params[:user])
  end
  
  # TODO: test
  def edit
    @user = User.find(params[:id])
    @user.password = nil
    if 1 == @user[:id]
      @groups = Group.find(:all, :conditions=>"id <> 1", :order=>'id')
    else
      @groups = Group.find(:all, :order=>'id')
    end
    render :partial=>'user/form'
  end
  
  # TODO: test
  def update
    if params[:groups]
      params[:user][:group_ids] = params[:groups].values.map {|v| v.to_i}
      params[:user][:group_ids] << 1 unless params[:user][:group_ids].include?(1)
    end
    @user = User.find(params[:id])
    @user.update_attributes(params[:user])
    @user.save
    unless @user.errors.empty?
      @groups = Group.find(:all, :order=>'id')
    end
    render :action=>'show'
  end
end
