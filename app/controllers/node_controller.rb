class NodeController < ApplicationController
  layout 'popup'
  helper MainHelper
  # test to here
  def test
    if request.get?
      @node = secure(Page) { Page.find(params[:id]) }
    else
      @node = secure(Page) { Page.find(params[:id]) }
      params[:node][:tag_ids] = [] unless params[:node][:tag_ids]
      @node.update_attributes(params[:node])
    end
  end
  
  # TODO: test
  # modifications of the node itself (dates, groups, revert editions, etc)
  def drive
    if params[:version_id]
      @node = secure_drive(Node) { Node.version(params[:version_id]) }
      # store the id used to preview versions
      session[:preview_id] = params[:version_id]
    else
      @node = secure_drive(Node) { Node.find(params[:id]) }
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  # TODO: test
  def move
    attrs = params[:node]
    @node = secure(Node) { Node.find(params[:id]) }
    if attrs[:parent_id]
      @node[:parent_id] = attrs[:parent_id]
    end
    if attrs[:name]
      @node[:name] = attrs[:name]
    end
    @node.save
  rescue ActiveRecord::RecordNotFound
    add_error'node not found'
  end
  
  # TODO: test
  def groups
    attrs = params[:node]
    @node = secure(Node) { Node.find(params[:id]) }
    @node.update_attributes(params[:node])
    @node.save
  end

  # TODO: test
  def attribute
    method = params[:attr].to_sym
    if [:v_text, :v_summary, :name, :path].include?(method)
      if params[:id] =~ /^\d+$/
        @node = secure(Node) { Node.find(params[:id]) }
      else
        @node = secure(Node) { Node.find_by_name(params[:id]) }
        raise ActiveRecord::RecordNotFound unless @node
      end
      if method == :path
        render :inline=>@node.rootpath.join('/')
      else
        @text = @node.send(method)
        if [:v_text, :v_summary].include?(method)
          render :inline=>"<%= zazen(@text) %>"
        else
          render :inline=>@text
        end
      end
    else
      render :inline=>method
    end
  rescue ActiveRecord::RecordNotFound
    render :inline=>trans('not found')
  end
  
  
  # change to ?
  
  #if @node.type != params[:node][:type]
  #  @node = @node.change_to(eval "#{params[:node][:type]}")
  #end
end
