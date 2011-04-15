class ColumnsController < ApplicationController
  before_filter :visitor_node
  before_filter :find_column, :except => [:index, :create, :new]
  before_filter :check_is_admin
  layout :admin_layout

  # GET /columns
  # GET /columns.xml
  def index
    roles = {}
    secure(Column) do
      @columns = Column.paginate(:all, :order => 'role_id ASC, name ASC', :per_page => 200, :page => params[:page]).sort! do |a, b|
        role_a = (roles[a.role_id] ||= a.role).name
        role_b = (roles[b.role_id] ||= b.role).name

        if role_a == role_b
          a.name <=> b.name
        else
          role_a <=> role_b
        end
      end
    end

    @column  = Column.new

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @columns }
    end
  end

  # GET /columns/1
  # GET /columns/1.xml
  def show

    respond_to do |format|
      format.html # show.html.erb
      format.js
      format.xml  { render :xml => @column }
    end
  end

  # GET /columns/new
  # GET /columns/new.xml
  def new
    @column = Column.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @column }
    end
  end

  # GET /columns/1/edit
  def edit
    respond_to do |format|
      format.html { render :partial => 'columns/form' }
      format.js   { render :partial => 'columns/form', :layout => false }
    end
  end

  # POST /columns
  # POST /columns.xml
  def create
    @column = Column.new(params[:column])

    respond_to do |format|
      if @column.save
        flash[:notice] = 'Column was successfully created.'
        format.html { redirect_to(@column) }
        format.js
        format.xml  { render :xml => @column, :status => :created, :location => @column }
      else
        format.html { render :action => "new" }
        format.js
        format.xml  { render :xml => @column.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /columns/1
  # PUT /columns/1.xml
  def update
    respond_to do |format|
      if @column.update_attributes(params[:column])
        flash[:notice] = 'Column was successfully updated.'
        format.html { redirect_to(@column) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @column.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /columns/1
  # DELETE /columns/1.xml
  def destroy
    @column.destroy

    respond_to do |format|
      format.html { redirect_to(columns_url) }
      format.js
      format.xml  { head :ok }
    end
  end

  protected
    def find_column
      @column = secure!(Column) { Column.find(params[:id])}
    end
end
