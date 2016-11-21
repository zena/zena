# TODO: Cleanup sites_controller now that we only support visitors for a single site !!
class SitesController < ApplicationController
  before_filter :remove_methods, :only => [:new, :create, :destroy]
  before_filter :find_site, :except => [:index, :create, :new, :clear_cache]
  before_filter :visitor_node
  before_filter :check_is_admin
  layout :admin_layout

  def index
    secure!(Site) do
      @sites = Site.paginate(:all, :order => 'host', :per_page => 20, :page => params[:page])
    end
    respond_to do |format|
      format.html # index.erb
      format.xml  { render :xml => @sites }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.xml  { render :xml => @site }
      format.js
    end
  end

  def jobs
    @jobs = @site.respond_to?(:jobs,true) ? @site.jobs : []
    respond_to do |format|
      format.html
    end
  end

  def edit
    respond_to do |format|
      format.html
      format.js   { render :partial => 'sites/form', :layout => false }
    end
  end

  def update
    respond_to do |format|
      if @site.update_attributes(params[:site])
        flash.now[:notice] = _('Site was successfully updated.')
        format.html { redirect_to site_path(@site) }
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
    secure!(Site) { Site.all }.each do |site|
      site.clear_cache
    end
    redirect_to '/'
  end

  def action
    if Site::ACTIONS.include?(params[:do])
      @site.send(params[:do])
      flash.now[:notice] = _("#{params[:do]} done.")
    else
      flash.now[:error] = _("Invalid action '%{action}'.") % {:action => params[:do]}
    end
  end

  protected
    def remove_methods
      raise ActiveRecord::RecordNotFound
    end

    def find_site
      @site = secure!(Site) { Site.find(params[:id])}
    end

end
