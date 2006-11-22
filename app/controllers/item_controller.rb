class ItemController < ApplicationController
  # test to here
  def test
    if request.get?
      @item = secure(Page) { Page.find(params[:id]) }
    else
      @item = secure(Page) { Page.find(params[:id]) }
      params[:item][:tag_ids] = [] unless params[:item][:tag_ids]
      @item.update_attributes(params[:item])
    end
  end
  
  # modifications of the item itself (dates, groups, revert editions, etc)
  def drive
    if params[:version_id]
      @item = secure_drive(Item) { Item.version(params[:version_id]) }
    else
      @item = secure_drive(Item) { Item.find(params[:id]) }
    end
  rescue ActiveRecord::RecordNotFound
    render :nothing=>true
  end
  
  # change to ?
  
  #if @item.type != params[:item][:type]
  #  @item = @item.change_to(eval "#{params[:item][:type]}")
  #end
end
