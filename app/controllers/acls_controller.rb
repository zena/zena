class AclsController < ApplicationController
  # GET /acls
  # GET /acls.xml
  def index
    @acls = Acl.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @acls }
    end
  end

  # GET /acls/1
  # GET /acls/1.xml
  def show
    @acl = Acl.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @acl }
    end
  end

  # GET /acls/new
  # GET /acls/new.xml
  def new
    @acl = Acl.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @acl }
    end
  end

  # GET /acls/1/edit
  def edit
    @acl = Acl.find(params[:id])
  end

  # POST /acls
  # POST /acls.xml
  def create
    @acl = Acl.new(params[:acl])

    respond_to do |format|
      if @acl.save
        format.html { redirect_to(@acl, :notice => 'Acl was successfully created.') }
        format.xml  { render :xml => @acl, :status => :created, :location => @acl }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @acl.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /acls/1
  # PUT /acls/1.xml
  def update
    @acl = Acl.find(params[:id])

    respond_to do |format|
      if @acl.update_attributes(params[:acl])
        format.html { redirect_to(@acl, :notice => 'Acl was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @acl.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /acls/1
  # DELETE /acls/1.xml
  def destroy
    @acl = Acl.find(params[:id])
    @acl.destroy

    respond_to do |format|
      format.html { redirect_to(acls_url) }
      format.xml  { head :ok }
    end
  end
end
