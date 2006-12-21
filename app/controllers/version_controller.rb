class VersionController < ApplicationController
  layout 'popup'
  helper MainHelper
  
  def show
    @item = secure(Item) { Item.version(params[:id]) }
    render_and_cache(:cache=>false)
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  def edit
    if params[:id]
      @item = secure(Item) { Item.version(params[:id]) }
    elsif params[:item_id]
      @item = secure_write(Item) { Item.find(params[:id]) }
    end
    if !@item.edit!
      page_not_found
    else
      # store the id used to preview when editing
      session[:preview_id] = params[:id]
      render_form
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  # preview when editing item
  def preview
    @preview_id = session[:preview_id]
    if params[:item]
      # redaction
      @item = secure_write(Item) { Item.find(params[:item][:id]) }
      @v_title   = params[:item][:v_title]
      @v_summary = params[:item][:v_summary]
      @v_text    = params[:item][:v_text]
    else
      # drive view
      @item = secure(Item) { Item.version(params[:id]) }
      @v_title   = @item.v_title
      @v_summary = @item.v_summary
      @v_text    = @item.v_text
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  # This is a helpers used when creating the css for the site. They have no link with the database
  def css_preview
    file = params[:css].gsub('..','')
    path = File.join(RAILS_ROOT, 'public', 'stylesheets', file)
    if File.exists?(path)
      if session[:css] && session[:css] == File.stat(path).mtime
        render :nothing=>true
      else
        session[:css] = File.stat(path).mtime
        @css = File.read(path)
      end
    else
      render :nothing=>true
    end
  end
  
  
  def save
    params[:item].delete(:preview_id)
    # use current context.
    @item = secure_write(Item) { Item.find(params[:item][:id]) }
    params[:item].delete(:file) if params[:item][:file] == ""
    parse_dates(params[:item])
    if @item.update_attributes(params[:item])
      session[:notice] = trans "Redaction saved."
    else
      flash[:error] = trans "Redaction could not be saved"
      render_form
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  def propose
    item = secure(Item) { Item.version(params[:id]) }
    if item.propose
      flash[:notice] = trans "Redaction proposed for publication."
      redirect_to @request.env['HTTP_REFERER'] #:action=> 'show', :id => item.v_id
    else
      page_not_found
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  def refuse
    item = secure(Item) { Item.version(params[:id]) }
    if item.refuse
      flash[:notice] = "Proposition refused."
      redirect_to @request.env['HTTP_REFERER'] #:action => 'show', :id => item.v_id
    else
      page_not_found
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  def publish
    item = secure(Item) { Item.version(params[:id]) }
    if item.publish
      flash[:notice] = "Redaction published."
      redirect_to @request.env['HTTP_REFERER'] #redirect_to :action => 'show', :id => item.v_id
    else
      flash[:error] = "Could not publish."
      page_not_found
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  def remove
    item = secure(Item) { Item.version(params[:id]) }
    if item.remove
      flash[:notice] = "Publication removed."
      redirect_to @request.env['HTTP_REFERER'] #:action => 'show', :id => item.v_id
    else
      flash[:error] = "Could not remove plublication."
      page_not_found
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  # TODO: test
  def unpublish
    item = secure(Item) { Item.version(params[:id]) }
    if item.unpublish
      flash[:notice] = "Publication removed."
      redirect_to @request.env['HTTP_REFERER'] #:action => 'show', :id => item.v_id
    else
      flash[:error] = "Could not remove plublication."
      page_not_found
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
end