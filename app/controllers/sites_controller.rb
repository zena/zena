class SitesController < ApplicationController
  before_filter :visitor_node
  before_filter :find_site, :except => [:index, :create, :new]
  before_filter :check_is_admin
  layout :admin_layout
  
  def index
    
    @site_pages, @sites = nil, nil
    secure!(Site) do
      @site_pages, @sites = paginate :sites, :per_page => 20, :order => 'name'
    end
    respond_to do |format|
      format.html # index.erb
      format.xml  { render :xml => @sites }
    end
  end

  def show
    respond_to do |format|
      format.html # show.erb
      format.xml  { render :xml => @site }
      format.js
    end
  end
  
  def new
    # This is not possible through the web interface. Use rake mksite.
    raise ActiveRecord::RecordNotFound
  end

  def edit
    respond_to do |format|
      format.html { render :partial => 'sites/form' }
      format.js   { render :partial => 'sites/form', :layout => false }
    end
  end
  
  def create
    # This is not possible through the web interface. Use rake mksite.
    raise ActiveRecord::RecordNotFound
  end
  
  def update
    @site = Site.find(params[:id])

    respond_to do |format|
      if @site.update_attributes(params[:site])
        flash[:notice] = 'Site was successfully updated.'
        format.html { redirect_to site_url(@site) }
        format.js
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.js
        format.xml  { render :xml => @site.errors }
      end
    end
  end

  def destroy
    # This is not possible through the web interface
    raise ActiveRecord::RecordNotFound
  end
  
  protected
    def visitor_node
      @node = visitor.contact
    end
    
    def find_site
      @site = secure!(Site) { Site.find(params[:id])}
    end
end
