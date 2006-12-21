class AdminController < ApplicationController
  layout 'admin'
  before_filter :check_is_admin
  helper MainHelper
  helper_method :comments_bin_content
  
  # TODO:test
  def comments
    @comment_pages, @comments =
          paginate :comments, :order => 'status ASC, created_at DESC', :conditions=>"status > #{Zena::Status[:rem]}", :per_page => 20
    render :layout=>'admin'
  end
  
  # TODO: test
  def empty_comments_bin
    comments_bin_content.each do |c|
      c.destroy
    end
    @comments_bin_content = nil
  end
  
  # TODO: test
  def remove_comment
    @comment    = Comment.find(params[:id])
    @discussion = @comment.discussion
    @item = secure(Item) { Item.find(@discussion[:item_id]) }
    @comment.remove
    puts @comment.inspect
  rescue ActiveRecord::RecordNotFound
    render :nothing=>true
  end
  
  private
  
  def comments_bin_content
    @comments_bin_content ||= Comment.find(:all, :conditions=>['status <= ?', Zena::Status[:rem]])
  end
  
  def check_is_admin
    page_not_found unless user_groups.include?(2) || user_id == 2
    @admin = true
  end
end
