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
    else
      @item = secure_drive(Item) { Item.find(params[:id]) }
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  # TODO: test
  def move
    attrs = params[:item]
    @item = secure(Item) { Item.find(attrs[:id]) }
    if attrs[:parent_id]
      @item[:parent_id] = attrs[:parent_id]
    end
    if attrs[:name]
      @item[:name] = attrs[:name]
    end
    
    if @item.save
      redirect_to :prefix => url_prefix, :controller => 'web', :action=>'item', :path=>@item.parent.fullpath << @item.name
    else
      redirect_to :prefix => url_prefix, :controller => 'web', :action=>'item', :path=>@item.fullpath
    end  
  end
  
  # TODO: test
  def groups
    attrs = params[:item]
    @item = secure(Item) { Item.find(attrs[:id]) }
    if attrs[:inherit]
      @item[:inherit] = attrs[:inherit]
    end
    if attrs[:rgroup_id]
      @item[:rgroup_id] = attrs[:rgroup_id]
    end
    if attrs[:wgroup_id]
      @item[:wgroup_id] = attrs[:wgroup_id]
    end
    if attrs[:pgroup_id]
      @item[:pgroup_id] = attrs[:pgroup_id]
    end
    if @item.save
      flash[:notice] = t "Groups changed"
    else
      flash[:error] = t "Could not change groups #{@item.show_errors}"
    end
    redirect_to :prefix => url_prefix, :controller => 'web', :action=>'item', :path=>@item.fullpath
  end

  # TODO: test
  def attribute
    method = params[:attr].to_sym
    if [:v_text, :v_summary, :name, :path].include?(method)
      @item = secure(Item) { Item.find(params[:id]) }
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
