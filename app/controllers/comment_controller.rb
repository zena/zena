class CommentController < ApplicationController
  
  # TODO: test
  def new
    @item       = secure(Item) { Item.find(params[:id]) }
    if @item.can_comment?
      @reply_to   = params[:reply_to]
    else
      render :nothing=>true
    end
  end
  
  # TODO: test
  def create
  end
  
  # TODO: test
  def drive
    @discussion = Discussion.find(params[:id])
    @item = secure_drive(Item) { Item.find(@discussion[:item_id]) }
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
end
