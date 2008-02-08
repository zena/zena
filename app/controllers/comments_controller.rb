# FIXME: rewrite !
class CommentsController < ApplicationController
  before_filter :check_is_admin, :only=>[:index, :empty_bin]
  helper_method :bin_content
  
  # TODO: test
  def reply_to
    @reply_to   = Comment.find(params[:id])
    @discussion = @reply_to.discussion
    @node = secure(Node) { Node.find(@discussion[:node_id]) }
    if @node && @node.can_comment?
      @comment = Comment.new(:reply_to=>@reply_to[:id], :discussion_id=>@discussion[:id])
    else
      render :nothing=>true
    end
  end
  
  # TODO: test
  def create
    @node = secure(Node) { Node.find(params[:node][:id]) }
    unless @node && @comment = @node.add_comment(params[:comment])
      processing_error 'cannot comment'
    end
  end
  
  # TODO: test
  def edit
    @comment    = Comment.find(params[:id])
    @discussion = @comment.discussion
    @node = secure(Node) { Node.find(@discussion[:node_id]) }
    @edit = true
    unless @node && @node.can_comment? && @comment[:user_id] == visitor.id
      render :nothing=>true
    end
  end
  
  # TODO: test
  def update
    @comment    = Comment.find(params[:comment][:id])
    @discussion = @comment.discussion
    @node = secure(Node) { Node.find(@discussion[:node_id]) }
    if @node && @node.can_comment? && @comment[:user_id] == visitor.id || visitor.id == 2
      [:user_id, :discussion_id, :reply_to].each { |sym| params[:comment].delete(sym) }
      @comment.update_attributes(params[:comment] )
    else
      render :nothing=>true
    end
  end
  
  # TODO: test
  def remove
    @comment    = Comment.find(params[:id])
    @discussion = @comment.discussion
    @node = secure(Node) { Node.find(@discussion[:node_id]) }
    if @node && visitor.is_admin? || @node.can_drive?
      @comment.remove
    else
      render :nothing=>true
    end
  end
  
  # TODO: test
  def publish
    @comment    = Comment.find(params[:id])
    @discussion = @comment.discussion
    @node = secure_drive(Node) { Node.find(@discussion[:node_id]) }
    if @node
      @comment.publish
    else
      render :nothing=>true
    end
  end
  ### === admin only
  
  # TODO:test
  def index
    @node = visitor.contact
    @comment_pages, @comments =
          paginate :comments, :order => 'status ASC, created_at DESC', :conditions=>"status > #{Zena::Status[:rem]}", :per_page => 20
    render :layout=>admin_layout
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
