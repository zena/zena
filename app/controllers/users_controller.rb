class UsersController < ApplicationController
  before_filter :find_user
  before_filter :check_is_admin,  :only   => [:index, :create, :edit ]
  before_filter :restrict_access, :except => [:home,  :preferences   ]
  layout :admin_layout
  
  # This view contains all the relevant information for a user's home in the CMS. From here, the
  # user can view the versions his is currently editing, he can publish content, etc
  # TODO: test
  def home
    params[:mode] = 'home'
    respond_to do |format|
      format.html { render_and_cache }
      format.xml  { render :xml => @node.to_xml }
    end
  end
  
  def show
    respond_to do |format|
      format.html { render_and_cache }
      format.js   # RJS action to display a single user in a list.
    end
  end
  
  # Show the list of users. Rendered in the admin layout.
  def index
    @user_pages, @users = nil, nil
    secure(User) do
      @user_pages, @users = paginate :users, :order => 'id', :per_page => 20
      @users # leave this: used by 'secure' as return value
    end
    @groups = secure(Group) { Group.find(:all, :order=>'id') }
    @user   = secure(User)    { User.new }
    respond_to do |format|
      format.html { render :action => 'index' }
    end
  end
  
  def preferences
    respond_to do |format|
      format.html # preferences.html.erb
    end
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
    
    @update = params.delete(:update)
    
    # TODO: test
    if params[:user][:password]
      if params[:user][:password].strip.size < 6
        @user.errors.add('password', 'too short')
      end
      if params[:user][:password] != params[:user][:retype_password]
        @user.errors.add('retype_password', 'does not match new password')
      end
      if !@user.password_is?(params[:user][:old_password])
        @user.errors.add('old_password', "not correct")
      end
      if @user.errors.empty?
        @user.password = params[:user][:password]
        params[:user].delete(:password)
        params[:user].delete(:retype_password)
        params[:user].delete(:old_passowrd)
      end
    end

    # only accept changes on the following fields through this interface
    params[:user].delete(:lang) unless visitor.site.lang_list.include?(params[:lang])
    
    if params[:groups]
      params[:user][:group_ids] = params[:groups].values.map {|v| v.to_i}
      params[:user][:group_ids] << 1 unless params[:user][:group_ids].include?(1)
    end
    
    if @user.errors.empty?
      @user.update_attributes(params[:user])
      if @user.errors.empty?
        flash[:notice] = trans 'information successfully updated'
      else
        flash[:error ] = trans 'could not update user'
      end
    end
    
    respond_to do |format|
      format.html # TODO
      format.js
    end
  end
  
  protected
    # Find the user or use the current visitor
    def find_user
      if params[:id]
        @user = secure(User) { User.find(params[:id]) }
      else
        @user = visitor
      end
      @node = @user.contact
    end
    
    # Restrict access some actions to administrators (used as a before_filter)
    def restrict_access
      return true if request.method == :get
      if visitor.is_admin?
        @admin = true
      elsif @user[:id] == visitor[:id]
        if params[:user]
          # visitor changing his/her own info : restrict fields
          params[:user].each_keys do |k|
            params[:user].delete(k) unless [:login, :first_name, :name, :time_zone, :lang, :email, :password].include?(k.to_sym)
          end
        end
      else
        raise ActiveRecord::RecordNotFound if params[:user] # FIXME: replace this with a test on the html verb (should only accept get)
      end
    end
end
