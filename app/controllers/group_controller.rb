class GroupController < ApplicationController
  before_filter :check_is_admin
  helper MainHelper
  layout 'admin'
  
  # TODO: test?
  def edit
    redirect_to :action=>'list' if 1 == params[:id]
    @group = Group.find(params[:id])
    render :action=>'list'
  end
  
  # TODO: test
  def list
    @group_pages, @groups =
            paginate :groups, :order => 'name', :per_page => 20
    @users = User.find(:all, :order=>'name', :limit=>20)
  end
  
  def create
    
  end
end
