class GroupsController < ApplicationController
  before_filter :find_group
  before_filter :check_is_admin
  before_filter :get_users_list, :except => [:show, :update]
  before_filter :filter_users_ids, :only => [:create, :update]
  layout :admin_layout
  
  def show
  end
  
  def edit
  end
  
  def index
    @group_pages, @groups = nil, nil
    secure!(Group) do
      @group_pages, @groups = paginate :groups, :order => 'name', :per_page => 20
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
          redirect_to(:action => 'show')
        else
          get_users_list
          render(:action => 'edit')
        end
      end
      format.js   { render      :action => 'show' }
    end
  end
  
  protected
    def find_group
      if params[:id]
        raise ActiveRecord::RecordNotFound if params[:id] == visitor.site.public_group_id
        @group = secure!(Group) { Group.find(params[:id]) }
      end
      @node = visitor.contact
    end
    
    def get_users_list
      @users = secure!(User) { User.find(:all, :conditions => "status >= #{User::Status[:reader]}", :order=>'login') }
    end
    
    def filter_users_ids
      if params[:users]
        params[:group][:user_ids] = params[:users].values.map {|v| v.to_i}
      end
      params[:group][:user_ids].reject!{|id| id.blank? } if params[:group][:user_ids]
    end
end
