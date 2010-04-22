class ColumnsController < ApplicationController
  # GET /columns
  # GET /columns.xml
  def index
    @columns = Column.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @columns }
    end
  end

  # GET /columns/1
  # GET /columns/1.xml
  def show
    @column = Column.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
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
    @column = Column.find(params[:id])
  end

  # POST /columns
  # POST /columns.xml
  def create
    @column = Column.new(params[:column])

    respond_to do |format|
      if @column.save
        flash[:notice] = 'Column was successfully created.'
        format.html { redirect_to(@column) }
        format.xml  { render :xml => @column, :status => :created, :location => @column }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @column.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /columns/1
  # PUT /columns/1.xml
  def update
    @column = Column.find(params[:id])

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
    @column = Column.find(params[:id])
    @column.destroy

    respond_to do |format|
      format.html { redirect_to(columns_url) }
      format.xml  { head :ok }
    end
  end
end
