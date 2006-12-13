class LinkController < ApplicationController
  
  # TODO: test
  def create
    @item = secure_drive(Item) { Item.find(params[:link][:item_id]) }
    @method = params[:link][:role]
    other_id = nil
    if params[:link][:other_id].to_i == 0
      begin
        if other = secure(Item) { Item.find_by_name(params[:link][:other_id]) }
          other_id = other[:id]
        end
      end
    else
      other_id = params[:link][:other_id]
    end
    if other_id && @item.add_link(@method, other_id) && @item.save
      @link = @item.send(@method.to_sym, :conditions=>['items.id = ?', other_id])
      @link = @link[0] if @link.kind_of?(Array)
    end
  rescue ActiveRecord::RecordNotFound
    render :inline=>trans('not found')
  end
  
  # TODO: test
  def remove
    @item = secure_drive(Item) { Item.find(params[:item_id]) }
    @link_id = params[:id]
    if @item.remove_link(@link_id) && @item.save
      # html wanted : redirect_to :action=>'drive', :id=>params[:id]
      # flash[:notice] = trans "Link removed"
    else  
      flash[:error]  = trans "Could not remove link"
      render :action=>'drive'
    end
  #rescue ActiveRecord::RecordNotFound
  #  render :inline=>trans('not found')
  rescue Zena::AccessViolation  
    flash[:error]  = trans "Link not found"
    render :action=>'drive'
  end
end
