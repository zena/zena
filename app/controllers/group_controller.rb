class GroupController < ApplicationController
  before_filter :check_is_admin
  layout :admin_layout
  
  # TODO: test
  def show
    @group = Group.find(params[:id])
  end
  
  # TODO: test?
  def edit
    render :nothing=>true if 1 == params[:id]
    @group = Group.find(params[:id])
    @users = User.find(:all, :order=>'login')
    render :partial=>'group/form'
  end
  
  # TODO: test
  def list
    @group_pages, @groups =
            paginate :groups, :order => 'id', :per_page => 20
    @users = User.find(:all, :order=>'login', :limit=>20)
  end
  
  # TODO: test
  def create
    if params[:users]
      params[:group][:user_ids] = params[:users].values.map {|v| v.to_i}
    end
    @users = User.find(:all, :order=>'login')
    @group = Group.create(params[:group])
    # TODO: add new group to user session if admin or do not cache groups
  end
  
  # TODO: test
  def update
    render :nothing=>true if 1 == params[:id]
    if params[:users] && params[:id] != 3
      params[:group][:user_ids] = params[:users].values.map {|v| v.to_i}
    end
    @group = Group.find(params[:id])
    @group.update_attributes(params[:group])
    @group.save
    puts @group.inspect
    render :action=>'show'
  end
end
