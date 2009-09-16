class DiscussionsController < ApplicationController

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
    unless @node
      processing_error 'node not found'
    else
      @discussion = Discussion.create(params[:discussion])
    end
  end

  # TODO: test
  def remove
    get_discussion
    @discussion.destroy
  end

  private

  def get_discussion
    @discussion = Discussion.find(params[:id])
    @node = secure(Node) { Node.find(@discussion[:node_id]) }
    unless @node
      processing_error 'node not found'
    end
  end
end
