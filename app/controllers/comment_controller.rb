class CommentController < ApplicationController
  before_filter :check_is_admin, :only=>[:list, :empty_bin]
  helper MainHelper
  helper_method :bin_content
  
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
    unless @item.can_comment? && @comment[:user_id] == visitor_id
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
    if @item.can_comment? && @comment[:user_id] == visitor_id || visitor_id == 2
      [:user_id, :discussion_id, :reply_to].each { |sym| params[:comment].delete(sym) }
      @comment.update_attributes(params[:comment] )
    else
      render :nothing=>true
    end
  rescue ActiveRecord::RecordNotFound
    render :nothing=>true
  end
  
  # TODO: test
  def remove
    @comment    = Comment.find(params[:id])
    @discussion = @comment.discussion
    @item = secure(Item) { Item.find(@discussion[:item_id]) }
    if user_admin? || (@item.can_comment? && visitor_id == @comment[:user_id])
      @comment.remove
    else
      render :nothing=>true
    end
  rescue ActiveRecord::RecordNotFound
    render :nothing=>true
  end
  
  # TODO: test
  def publish
    @comment    = Comment.find(params[:id])
    @discussion = @comment.discussion
    @item = secure_drive(Item) { Item.find(@discussion[:item_id]) }
    @comment.publish
  rescue ActiveRecord::RecordNotFound
    render :nothing=>true
  end
  ### === admin only
  
  # TODO:test
  def list
    @comment_pages, @comments =
          paginate :comments, :order => 'status ASC, created_at DESC', :conditions=>"status > #{Zena::Status[:rem]}", :per_page => 20
    render :layout=>'admin'
  end
  
  # TODO: test
  def empty_bin
    bin_content.each do |c|
      c.destroy
    end
    # reset cached bin content
    @bin_content = nil
  end
  
  private
  
  def bin_content
    @bin_content ||= Comment.find(:all, :conditions=>['status <= ?', Zena::Status[:rem]])
  end
end
