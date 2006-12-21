class DiscussionController < ApplicationController
  helper MainHelper
  
  # TODO: test
  def show
    get_discussion
    @comments = @discussion.comments
  end
  
  # TODO: test
  def open
    get_discussion
    @discussion.update_attributes( :open => true )
    render :action=>'update'
  end
  
  # TODO: test
  def close
    get_discussion
    @discussion.update_attributes( :open => false )
    render :action=>'update'
  end
  
  # TODO: test
  def create
    @item = secure(Item) { Item.find(params[:discussion][:item_id])}
    @discussion = Discussion.create(params[:discussion])
  rescue ActiveRecord::RecordNotFound
    @error = trans 'item not found'
  end
  
  # TODO: test
  def remove
    get_discussion
    @discussion.destroy
  end
  
  private
  
  def get_discussion
    @discussion = Discussion.find(params[:id])
    @item = secure_drive(Item) { Item.find(@discussion[:item_id]) }
  rescue ActiveRecord::RecordNotFound
    @error = trans 'item not found'
  end
end
