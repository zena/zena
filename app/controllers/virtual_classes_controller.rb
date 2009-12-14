class VirtualClassesController < ApplicationController
  before_filter :visitor_node
  before_filter :find_virtual_class, :except => [:index, :create, :new, :import]
  before_filter :check_is_admin
  layout :admin_layout

  def index
    secure(VirtualClass) do
      @virtual_classes = VirtualClass.paginate(:all, :order => 'kpath', :per_page => 20, :page => params[:page])
    end
    @virtual_class  = VirtualClass.new
    respond_to do |format|
      format.html # index.erb
      format.xml  { render :xml => @virtual_classes }
    end
  end

  def export
    secure(VirtualClass) do
      @virtual_classes = VirtualClass.all
    end
    ###
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
        @virtual_class  = VirtualClass.new
        respond_to do |format|
          format.html { render :action => 'index' }
        end
      end
    end
  end

  def show
    respond_to do |format|
      format.html # show.erb
      format.xml  { render :xml => @virtual_class }
      format.js
    end
  end

  def new
    @virtual_class = VirtualClass.new

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
    @virtual_class = VirtualClass.new(params[:virtual_class])

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
    @virtual_class = VirtualClass.find(params[:id])

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
    def visitor_node
      @node = visitor.contact
    end

    def find_virtual_class
      @virtual_class = secure!(VirtualClass) { VirtualClass.find(params[:id])}
    end
end
