class VirtualClassesController < ApplicationController
  before_filter :find_virtual_class, :except => [:index, :create, :new, :import]
  before_filter :visitor_node
  before_filter :check_is_admin
  layout :admin_layout

  def index
    secure(VirtualClass) do
      @virtual_classes = Role.paginate(:all, :order => 'kpath', :per_page => 20, :page => params[:page])
    end

    last_kpath = @virtual_classes.last.kpath
    Node.native_classes.each do |kpath, klass|
      if kpath < last_kpath
        @virtual_classes << klass
      end
    end

    @virtual_classes.sort! do |a, b|
      if a.kpath == b.kpath
        # Order VirtualClass first
        b_type = b.kind_of?(Role) ? b.class.to_s : 'V' # sort real classes like VirtualClass
        a_type = a.kind_of?(Role) ? a.class.to_s : 'V'

        b_type <=> a_type
      else
        a.kpath <=> b.kpath
      end
    end

    @virtual_class  = VirtualClass.new('')

    respond_to do |format|
      format.html # index.erb
      format.xml  { render :xml => @virtual_classes }
    end
  end

  def export
    data = secure(VirtualClass) do
      VirtualClass.export
    end

    ### TODO
  end

  def import
    attachment = params[:attachment]
    if attachment.nil?
      flass[:error] = "Upload failure: no definitions."
      redirect_to :action => :index
    else
      data = YAML.load(attachment.read) rescue nil
      if data.nil?
        flash[:error] = "Could not parse yaml document"
        redirect_to :action => :index
      else
        @virtual_classes = secure(VirtualClass) { VirtualClass.import(data) }.paginate(:per_page => 200)
        @virtual_class  = VirtualClass.new('')
        respond_to do |format|
          format.html { render :action => 'index' }
        end
      end
    end
  end

  def show
    respond_to do |format|
      format.html # show.erb
      format.js
      format.xml  { render :xml => @virtual_class }
    end
  end

  def new
    @virtual_class = VirtualClass.new('')

    respond_to do |format|
      format.html # new.erb
      format.xml  { render :xml => @virtual_class }
    end
  end

  # TODO: test
  def edit
    respond_to do |format|
      format.html { render :partial => 'virtual_classes/form' }
      format.js   { render :partial => 'virtual_classes/form', :layout => false }
    end
  end

  def create
    type = params[:virtual_class].delete(:type)
    if type == 'Role'
      @virtual_class = Role.new(params[:virtual_class])
    else
      @virtual_class = VirtualClass.new(params[:virtual_class])
    end

    respond_to do |format|
      if @virtual_class.save
        flash[:notice] = 'VirtualClass was successfully created.'
        format.html { redirect_to virtual_class_url(@virtual_class) }
        format.js
        format.xml  { render :xml => @virtual_class, :status => :created, :location => virtual_class_url(@virtual_class) }
      else
        format.html { render :action => "new" }
        format.js
        format.xml  { render :xml => @virtual_class.errors }
      end
    end
  end

  def update
    respond_to do |format|
      if @virtual_class.update_attributes(params[:virtual_class])
        flash[:notice] = 'VirtualClass was successfully updated.'
        format.html { redirect_to virtual_class_url(@virtual_class) }
        format.js
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.js
        format.xml  { render :xml => @virtual_class.errors }
      end
    end
  end

  def destroy
    @virtual_class.destroy

    respond_to do |format|
      format.html { redirect_to virtual_classes_url }
      format.xml  { head :ok }
      format.js
    end
  end

  protected
    def find_virtual_class
      @virtual_class = secure!(VirtualClass) { Role.find(params[:id])}
    end
end
