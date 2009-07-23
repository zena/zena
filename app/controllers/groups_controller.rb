class GroupsController < ApplicationController
  before_filter :check_is_admin
  before_filter :find_group, :except => [:index, :new, :create]
  before_filter :find_node
  before_filter :get_users,  :except => [:show, :update]
  before_filter :get_groups, :except => [:show, :update, :index]
  before_filter :filter_users_ids, :only => [:create, :update]
  layout :admin_layout
  
  def show
  end
  
  def edit
    respond_to do |format|
      format.html
      format.js { render :partial => 'form' }
    end
  end
  
  def index
    secure!(Group) do
      @groups = Group.paginate(:all, :order => 'name', :per_page => 20, :page => params[:page])
    end
    @group = Group.new
    respond_to do |format|
      format.html
    end
  end
  
  def create
    @group = Group.create(params[:group])
  end
  
  def update
    @group.update_attributes(params[:group])
    
    respond_to do |format|
      format.html do 
        if @group.errors.empty?
          redirect_to :action => 'show'
        else
          get_users
          get_groups
          render :action => 'edit'
        end
      end
      format.js { render :action => 'show' }
    end
  end
  
  def destroy
    @group.destroy

    respond_to do |format|
      format.html do
        if @group.errors.empty?
          redirect_to :action => 'index' 
        else
          get_users
          get_groups # all groups are used by 'replace_by'
          render :action => 'edit'
        end
      end
      format.js   do
        render(:partial => 'form') unless @group.errors.empty?
      end
      format.xml  { head :ok }
    end
  end
  
  protected
    def find_group
      if params[:id]
        if params[:id].to_i == visitor.site.public_group_id
          params[:group].delete(:user_ids) if params[:group]
        end
        @group = secure!(Group) { Group.find(params[:id]) }
      end
    end
    
    def find_node
      @node = visitor.contact
    end
    
    def get_users
      @users  = secure!(User)  { User.find(:all, :conditions => "status >= #{User::Status[:reader]}", :order=>'login') }
    end
    
    def get_groups
      @groups = secure!(Group) { Group.find(:all, :order=>'name') }
    end
    
    def filter_users_ids
      if params[:users]
        params[:group][:user_ids] = params[:users].values.map {|v| v.to_i}
      end
      params[:group][:user_ids].reject!{|id| id.blank? } if params[:group][:user_ids]
    end
end
