require 'net/http' if ENABLE_ZENA_UP
class SitesController < ApplicationController
  before_filter :visitor_node
  before_filter :remove_methods, :only => [:new, :create, :destroy]
  before_filter :find_site, :except => [:index, :create, :new, :zena_up]
  before_filter :check_is_admin
  before_filter :check_can_zena_up, :only => [:zena_up]
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

  # Update source code and restart application
  def zena_up
    # FIXME: this will not work when we move to git...
    @current_rev = Zena::REVISION.strip.to_i

    if params[:rev]
      @target_rev = params[:rev].to_i
    else
      latest = Net::HTTP.get('svn.zenadmin.org', '/zena/')
      if latest =~ /Revision (\d+)/
        @target_rev = $1.strip.to_i
      else
        # error
      end
    end

    if @target_rev
      if params[:run] == 'start'
        if @current_rev >= @target_rev
          # up to date (do nothing)
        else
          `zena_up`
        end
        return redirect_to(:action => 'zena_up', :run => 'updating', :rev => @target_rev)
      elsif params[:run] == 'updating' && @current_rev < @target_rev
        # wait to finish
        @state = :wait
        headers["REFRESH"] = 30
      elsif @current_rev >= @target_rev
        # done
        @state = :done
        return redirect_to(:action => 'zena_up', :rev => @target_rev) if params[:run]
      else
        # status page
      end
    else
      # error
    end
  end

  def show
    respond_to do |format|
      format.html
      format.xml  { render :xml => @site }
      format.js
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
        flash[:notice] = 'Site was successfully updated.'
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
    @site.clear_cache

    @clear_cache_message = _("Cache cleared.")
  end

  protected
    def visitor_node
      @node = visitor.contact
    end

    def remove_methods
      raise ActiveRecord::RecordNotFound
    end

    def find_site
      @site = secure!(Site) { Site.find(params[:id])}
    end

    def check_can_zena_up
      ENABLE_ZENA_UP && visitor.is_admin?
    end
end
