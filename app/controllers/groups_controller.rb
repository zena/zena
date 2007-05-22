class GroupsController < ApplicationController
  before_filter :find_group
  before_filter :check_is_admin
  layout :admin_layout
  
  # TODO: test
  def show
  end
  
  # TODO: test?
  def edit
    get_users_list
    render :partial=>'groups/form'
  end
  
  # TODO: test
  def index
    @group_pages, @groups = nil, nil
    secure(Group) do
      @group_pages, @groups = paginate :groups, :order => 'name', :per_page => 20
      @groups # leave this: used by 'secure' as return value
    end
    get_users_list
    @group = secure(User)  { Group.new }
    respond_to do |format|
      format.html
    end
  end
  
  # TODO: test
  def create
    if params[:users]
      params[:group][:user_ids] = params[:users].values.map {|v| v.to_i}
    end
    get_users_list
    @group = Group.create(params[:group])
    # TODO: add new group to user session if admin or do not cache groups
  end
  
  # TODO: test
  def update
    @group.update_attributes(params[:group])
    
    respond_to do |format|
      format.html # TODO
      format.js { render :action=>'show' }
    end
  end
  
  protected
    def find_group
      if params[:id]
        raise ActiveRecord::RecordNotFound if params[:id] == visitor.site.public_group_id
        @group = secure(Group) { Group.find(params[:id]) }
      end
      @node = visitor.contact
    end
    
    def get_users_list
      @users = secure(User) { User.find(:all, :conditions => "status >= #{User::Status[:reader]}", :order=>'login') }
    end
end
