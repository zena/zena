class AclsController < ApplicationController
  before_filter :check_is_admin
  before_filter :find_acl, :except => [:index, :new, :create]
  before_filter :visitor_node
  layout :admin_layout

  def index
    secure(Acl) do
      @acls = Acl.paginate(:all, :order => 'priority DESC, name ASC', :per_page => 20, :page => params[:page])
    end
    @acl = Acl.new

    respond_to do |format|
      format.html # index.html.erb
    end
  end

  def show
    respond_to do |format|
      format.html { render :file => admin_layout, :layout => false }
      format.js
    end
  end

  def edit
    respond_to do |format|
      format.html
      format.js { render :partial => 'form' }
    end
  end

  def create
    @acl = secure(Acl) {Acl.create(acl_attributes)}
  end

  def update
    @acl.update_attributes(acl_attributes)

    respond_to do |format|
      format.html do
        if @acl.errors.empty?
          redirect_to :action => 'show'
        else
          render :action => 'edit'
        end
      end
      format.js
    end
  end

  def destroy
    @acl.destroy

    respond_to do |format|
      format.html do
        if @acl.errors.empty?
          redirect_to :action => 'index'
        else
          render :action => 'edit'
        end
      end
      format.js   do
        render(:partial => 'form') unless @acl.errors.empty?
      end
      format.xml  { head :ok }
    end
  end

  private
    def find_acl
      if params[:id]
        @acl = secure!(Acl) { Acl.find(params[:id]) }
      end
    end

    def acl_attributes
      return {} unless acl_params = params[:acl]
      if skin_zip = acl_params[:exec_skin_id]
        acl_params[:exec_skin_id] = skin_zip.blank? ? '' : Node.translate_pseudo_id(skin_zip)
      end
      acl_params
    end
end
