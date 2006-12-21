class CommentController < ApplicationController
  def new
    @item       = secure(Item) { Item.find(params[:id]) }
    if @item.can_comment?
      @reply_to   = params[:reply_to]
    else
      render :nothing=>true
    end
  end
  
  def create
  end
end
