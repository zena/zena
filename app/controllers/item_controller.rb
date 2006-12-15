class ItemController < ApplicationController
  layout 'popup'
  helper MainHelper
  # test to here
  def test
    if request.get?
      @item = secure(Page) { Page.find(params[:id]) }
    else
      @item = secure(Page) { Page.find(params[:id]) }
      params[:item][:tag_ids] = [] unless params[:item][:tag_ids]
      @item.update_attributes(params[:item])
    end
  end
  
  # TODO: test
  # modifications of the item itself (dates, groups, revert editions, etc)
  def drive
    if params[:version_id]
      @item = secure_drive(Item) { Item.version(params[:version_id]) }
      # store the id used to preview versions
      session[:preview_id] = params[:version_id]
    else
      @item = secure_drive(Item) { Item.find(params[:id]) }
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  # TODO: test
  def move
    attrs = params[:item]
    @item = secure(Item) { Item.find(params[:id]) }
    if attrs[:parent_id]
      @item[:parent_id] = attrs[:parent_id]
    end
    if attrs[:name]
      @item[:name] = attrs[:name]
    end
    @item.save
  rescue ActiveRecord::RecordNotFound
    @error = trans 'item not found'
  end
  
  # TODO: test
  def groups
    attrs = params[:item]
    @item = secure(Item) { Item.find(params[:id]) }
    @item.update_attributes(params[:item])
    @item.save
  end

  # TODO: test
  def attribute
    method = params[:attr].to_sym
    if [:v_text, :v_summary, :name, :path].include?(method)
      if params[:id] =~ /^\d+$/
        @item = secure(Item) { Item.find(params[:id]) }
      else
        @item = secure(Item) { Item.find_by_name(params[:id]) }
        raise ActiveRecord::RecordNotFound unless @item
      end
      if method == :path
        render :inline=>@item.rootpath.join('/')
      else
        @text = @item.send(method)
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
  
  #if @item.type != params[:item][:type]
  #  @item = @item.change_to(eval "#{params[:item][:type]}")
  #end
end
