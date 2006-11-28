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
      render_form
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  # preview when editing item
  def preview
    if params[:item]
      params[:item].delete(:c_file)
      @item = secure_write(Item) { Item.find(params[:item][:id]) }
      # FIXME: 'edit_preview' parses utf-8 very badly !!!
      @item.edit_preview(params[:item])
    else
      @item = secure(Item) { Item.version(params[:version_id]) }
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  def save
    # use current context.
    @item = secure_write(Item) { Item.find(params[:item][:id]) }
    params[:item].delete(:file) if params[:item][:file] == ""
    if @item.update_attributes(params[:item])
      flash[:notice] = trans "Redaction saved."
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
      redirect_to :action=> 'show', :id => item.v_id
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
      redirect_to :action => 'show', :id => item.v_id
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
      redirect_to :action => 'show', :id => item.v_id
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
      redirect_to :action => 'show', :id => item.v_id
    else
      flash[:error] = "Could not remove plublication."
      page_not_found
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  # def redit
  #   item = secure(Item) { Item.version(params[:id]) }
  #   if item.redit
  #     flash[:notice] = "Version turned back into a redaction."
  #     redirect_to :action => 'show', :id => item.v_id
  #   else
  #     flash[:error] = "Could not re-edit the version."
  #     page_not_found
  #   end
  # rescue ActiveRecord::RecordNotFound
  #   page_not_found
  # end
  
end