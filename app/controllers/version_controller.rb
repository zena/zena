class VersionController < ApplicationController
  
  def edit
    if params[:id]
      @item = secure(Item) { Item.version(params[:id]) }
    elsif params[:item_id]
      @item = secure_write(Item) { Item.find(params[:id]) }
    end
    if @item.edit
      render :layout=>'popup'
    else
      render :nothing=>true
    end
  rescue ActiveRecord::RecordNotFound
    render :nothing=>true
  end
  
  # test to here
  
  # preview when editing item
  def preview
    if params[:item]
      @item = secure_write(Item) { Item.find(params[:item][:id]) }
      # FIXME: 'edit_preview' parses utf-8 very badly !!!
      @item.edit_preview(params[:item])
    else
      @item = secure(Item) { Item.version(params[:version_id]) }
    end
  rescue ActiveRecord::RecordNotFound
    render :nothing=>true
  end
  
  def save
    if params[:version]
      # use a specific version as the base for the new redaction.
      @item = secure_write(Item) { Item.version(params[:version][:id]) }
    else
      # use current context.
      @item = secure_write(Item) { Item.find(params[:item][:id]) }
    end
    
    #if @item.type != params[:item][:type]
    #  @item = @item.change_to(eval "#{params[:item][:type]}")
    #end
    if @item.edit(params[:item])
      flash[:notice] = "Redaction saved."
      render :layout => 'popup'
    else
      render :layout=>'popup', :action => 'edit'
    end
  #rescue ActiveRecord::RecordNotFound
   # render :nothing=>true
  end
  
  def propose
    item = secure(Item) { Item.version(params[:version_id]) }
    if item.propose
      flash[:notice] = "Redaction proposed for publication."
    else
      flash[:error] = "Could not propose redaction for publication."
    end
    redirect_to :prefix=> url_prefix, :controller => 'web', :action=> 'version', :id => item.v_id
  rescue ActiveRecord::RecordNotFound
    render :nothing=>true
  end
  
  def refuse
    item = secure(Item) { Item.version(params[:version_id]) }
    if item.refuse
      flash[:notice] = "Proposition refused."
    else
      flash[:error] = "Could not refuse."
    end
    redirect_to :prefix=> url_prefix, :controller => 'web', :action=> 'version', :id => item.v_id
  rescue ActiveRecord::RecordNotFound
    render :nothing=>true
  end
  
  def publish
    item = secure(Item) { Item.version(params[:version_id]) }
    if item.publish
      flash[:notice] = "Redaction published."
      Pcache.expire_cache(:plug=>:news) if item.kind_of?(Note)
    else
      flash[:error] = "Could not publish."
    end
    redirect_to :prefix=> url_prefix, :controller => 'web', :action=> 'version', :id => item.v_id
  rescue ActiveRecord::RecordNotFound
    render :nothing=>true
  end
  
  def remove
    item = secure(Item) { Item.version(params[:version_id]) }
    if item.remove
      flash[:notice] = "Publication removed."
      Pcache.expire_cache(:plug=>:news) if item.kind_of?(Note)
    else
      flash[:error] = "Could not remove plublication."
    end
    redirect_to :prefix=> url_prefix, :controller => 'web', :action=> 'version', :id => item.v_id
  rescue ActiveRecord::RecordNotFound
    render :nothing=>true
  end
  
  def redit
    item = secure(Item) { Item.version(params[:version_id]) }
    if item.redit
      flash[:notice] = "Version turned back into a redaction."
    else
      flash[:error] = "Could not re-edit the version."
    end
    redirect_to :prefix=> url_prefix, :controller => 'web', :action=> 'version', :id => item.v_id
  rescue ActiveRecord::RecordNotFound
    render :nothing=>true
  end
  
end
=begin

def show
  elsif params[:version_id]
    @item = secure(Item) { Item.version(params[:version_id]) }
 Show a version
def version
  if params[:id]
    @item = secure(Item) { Item.version(params[:id]) }
  end
  if @item && @item.title
    render_and_cache
  else
    page_not_found 
  end
rescue ActiveRecord::RecordNotFound
  page_not_found
end

=end


=begin
  # Show versions list for an item with preview, roll, etc buttons.
  def history
    @item = secure(Item) { Item.find(params[:id]) }
    raise ActiveRecord::RecordNotFound unless @item.can_publish?
    @versions = @item.versions.find(:all, :order=>'id DESC')
    render :layout=>false
  rescue ActiveRecord::RecordNotFound
    render :nothing=>true
  end
  # Publish a version, replacing previous edition.
  def publish
    version = Version.find(params[:version][:id])
    if version.item.can_publish?(user_id, user_groups)
      if version.publish
        redirect_to :controller => 'web', :action=>'item', :id=>version.item.id, :lang=>version.lang
      else
        flash[:notice] = trans "An error occured, version could not be published."
        redirect_to :controller => 'web', :action=>'version', :id=>params[:version][:id]
      end
    else
      redirect_to :controller => 'web', :action=>'page_not_found'
    end
  end
  
  
  # rollback item
  def rollback
    item = secure(Item) { Item.find(params[:id]) }
    flash[:notice] = trans "Page rolled back to a previous version."
    redirect_to(:controller => 'web', :action=>'item', :path=>item.fullpath) #, :version=>version.id)
  end


  # edit item
  def live_edit_item
    if params[:edition]
      if session[:user]
        user = User.find(session[:user][:id])
      else
        user = User.find(1)
      end
      item = secure(Item) { Item.find(params[:item][:id]) }
      version = Version.new(params[:edition])
      version.item = item
      version.user = user
      version.save
      version.publish
      redirect_to(:controller => 'web', :action=>'item', :path=>item.fullpath) #, :version=>version.id)
    else
      @edition = Version.new
      @item = secure(Item){ Item.find(params[:id]) }
      @edition = @item.edition
      @edition.lang = lang
      render(:layout=>false)
    end
  end
  
end
=end