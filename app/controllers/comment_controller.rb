class CommentController < ApplicationController
  
  # TODO: test
  def reply_to
    @reply_to   = Comment.find(params[:id])
    @discussion = @reply_to.discussion
    @item = secure(Item) { Item.find(@discussion[:item_id]) }
    if @item.can_comment?
      @comment = Comment.new(:reply_to=>@reply_to[:id], :discussion_id=>@discussion[:id])
    else
      render :nothing=>true
    end
  rescue ActiveRecord::RecordNotFound
    render :nothing=>true
  end
  
  # TODO: test
  def create
    @item = secure(Item) { Item.find(params[:item][:id]) }
    @comment = @item.add_comment(params[:comment])
  rescue ActiveRecord::RecordNotFound  
    @error = trans 'item not found'
  end
  
  # TODO: test
  def edit
    @comment    = Comment.find(params[:id])
    @discussion = @comment.discussion
    @item = secure(Item) { Item.find(@discussion[:item_id]) }
    @edit = true
    unless @item.can_comment? && @comment[:user_id] == user_id
      render :nothing=>true
    end
  rescue ActiveRecord::RecordNotFound
    render :nothing=>true
  end
  
  # TODO: test
  def update
    @comment    = Comment.find(params[:comment][:id])
    @discussion = @comment.discussion
    @item = secure(Item) { Item.find(@discussion[:item_id]) }
    if @item.can_comment? && @comment[:user_id] == user_id || user_id == 2
      [:user_id, :discussion_id, :reply_to].each { |sym| params[:comment].delete(sym) }
      @comment.update_attributes(params[:comment] )
    else
      render :nothing=>true
    end
  rescue ActiveRecord::RecordNotFound
    render :nothing=>true
  end
  
end
