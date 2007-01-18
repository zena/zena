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
    @node = secure(Node) { Node.find(params[:discussion][:node_id])}
    @discussion = Discussion.create(params[:discussion])
  rescue ActiveRecord::RecordNotFound
    add_error'node not found'
  end
  
  # TODO: test
  def remove
    get_discussion
    @discussion.destroy
  end
  
  private
  
  def get_discussion
    @discussion = Discussion.find(params[:id])
    @node = secure_drive(Node) { Node.find(@discussion[:node_id]) }
  rescue ActiveRecord::RecordNotFound
    add_error'node not found'
  end
end
