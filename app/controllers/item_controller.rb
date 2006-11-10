class ItemController < ApplicationController
  
  # test to here
  
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
end
