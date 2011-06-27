class UsersController < ApplicationController
  before_filter :find_user
  before_filter :visitor_node
  before_filter :check_is_admin,  :only => [:index, :create, :dev_skin]
  before_filter :restrict_access, :except => [:rescue]
  layout :admin_layout

  def show
    respond_to do |format|
      format.html { render :file => admin_layout, :layout => false }
      format.js
    end
  end

  # Show the list of users. Rendered in the admin layout.
  def index
    secure!(User) do
      @users = User.paginate(:all, :order => 'status DESC, login ASC', :page => params[:page], :per_page => 20)
    end

    get_groups_list
    @user   = User.new
    respond_to do |format|
      format.html
    end
  end

  def preferences
    respond_to do |format|
      format.html # preferences.html.erb
    end
  end

  # nil ==> no dev mode
  # -1  ==> rescue skin
  # 0   ==> normal skin
  # xx  ==> fixed skin
  def dev_skin(skin_id = params['skin_id'])
    visitor.update_attributes('dev_skin_id' => skin_id)

    if request.referer && !(request.referer =~ /login/)
      redirect_to request.referer
    else
      redirect_to home_path(:prefix => prefix)
    end
  end

  # Use $default skin for rendering
  def rescue
    if visitor.is_admin?
      dev_skin(-1)
    else
      save_after_login_path
      redirect_to login_path
    end
  end

  # TODO: test
  def create
    if params[:groups]
      params[:user][:group_ids] = params[:groups].values
    end

    get_groups_list

    @user = secure(User) { User.create(params[:user]) }
  end

  # TODO: test
  def edit
    @user.password = nil
    get_groups_list
    respond_to do |format|
      format.html { render :partial => 'users/form' }
      format.js   { render :partial => 'users/form', :layout => false }
    end
  end

  def update
    if skin_id = params['user']['dev_skin_id']
      return dev_skin(skin_id)
    end

    @update = params.delete(:update)

    opts = params[:user]
    unless opts[:password].blank?
      if opts[:password].strip.size < 6
        @user.errors.add('password', 'too short')
      end

      if !visitor.is_admin? || opts[:retype_password]
        if opts[:password] != opts[:retype_password]
          @user.errors.add('retype_password', 'does not match new password')
        end
      end

      if !visitor.is_admin? || @user.id == visitor.id
        if !@user.valid_password?(opts[:old_password])
          @user.errors.add('old_password', "not correct")
        end
      end

      if @user.errors.empty?
        @user.password = opts[:password]
        opts.delete(:password)
        opts.delete(:retype_password)
        opts.delete(:old_password)
      end
    end

    if @user.errors.empty?
      @user.update_attributes(params[:user])
      if @user.errors.empty?
        flash.now[:notice] = _('information successfully updated')
      else
        flash.now[:error ] = _('could not update user')
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
        @user = secure!(User) { User.find(params[:id]) }
      else
        @user = visitor
      end
    end

    def get_groups_list
      @groups = secure!(Group) { Group.find(:all, :order => 'name ASC') }
    end

    # Only allow if user is admin or the current user is the visitor
    # TODO: test
    def restrict_access
      if visitor.is_admin?
        @admin = true
        if params[:user] && params[:node]
          params[:user][:node_attributes] = params[:node]
        end
      elsif @user[:id] == visitor[:id]
        # Cannot change linked node
        if params[:user]
          # visitor changing his/her own info : restrict fields
          params[:user].keys.each do |k|
            params[:user].delete(k) unless [:login, :time_zone, :lang, :password, :time_zone, :retype_password, :old_password].include?(k.to_sym)
          end
        end
      else
        raise ActiveRecord::RecordNotFound
      end
    end
end
