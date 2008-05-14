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

  def clear_cache
    public_path = "#{SITES_ROOT}#{@site.public_path}"
    
    if File.exist?(public_path)
      Dir.foreach(public_path) do |elem|
        next unless elem =~ /^(\w\w\.html|\w\w)$/
        FileUtils.rmtree(File.join(public_path, elem))
      end
      
      Site.connection.execute "DELETE FROM caches WHERE site_id = #{@site.id}"
      Site.connection.execute "DELETE FROM cached_pages_nodes WHERE cached_pages_nodes.node_id IN (SELECT nodes.id FROM nodes WHERE nodes.site_id = #{@site.id})"
      Site.connection.execute "DELETE FROM cached_pages WHERE site_id = #{@site.id}"
      
    end
    
    zafu_path = "#{SITES_ROOT}#{@site.zafu_path}"
    if File.exist?(zafu_path)
      FileUtils.rmtree(zafu_path)
    end
    
    @clear_cache_message = _("Cache cleared.")
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
