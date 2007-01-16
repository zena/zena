class LinkController < ApplicationController
  
  # create a link given the item id 'link[item_id]', the role 'link[role]' and the target id 'link[other_id]'. The target id
  # can also be a name
  # TODO: test multiple/single values
  def create
    @item = secure_drive(Item) { Item.find(params[:link][:item_id]) }
    if params[:item]
      # update item links with list
      box = params[:item][:box]
      params[:item].delete(:box)
      if params[:item].keys.size == 0
        # empty => cleared
        if @item.respond_to?("#{box}_id=".to_sym)
          # unique
          @item.send("#{box}_id=".to_sym, nil)
        else
          # multiple
          @item.send("#{box.singularize}_ids=".to_sym, nil)
        end
        @item.save
      else
        @method = params[:item].keys[0]
        unless @method =~ /^(.+)_id(s|)$/
          # bad method...
          add_error'unknown link role'
        else
          @item.send("#{@method}=".to_sym, params[:item][@method])
          @item.save
        end
      end
    else
      # add a link
      @method = params[:link][:role]
      other_id = nil
      if params[:link][:other_id] =~ /^\d+$/
        other_id = params[:link][:other_id].to_i
      else
        begin
          if other = secure(Item) { Item.find_by_name(params[:link][:other_id]) }
            other_id = other[:id]
          end
        end
      end
      if other_id && @item.add_link(@method, other_id) && @item.save
        @link = @item.send(@method.to_sym, :conditions=>['items.id = ?', other_id])
        @link = @link[0] if @link.kind_of?(Array)
      end
    end
  rescue ActiveRecord::RecordNotFound
    add_error'item not found'
  end
  
  def select_for
    @item = secure(Item) { Item.find(params[:id]) }
    @item.class.roles.each do |r|
      if r[:method].to_s == params[:role]
        @role = r
        break
      end
    end
    if @role
      if @role[:collector]
        render :inline=>"<%= select_id('link', 'other_id', :show=>:path) %>"
      else
        render :inline=>"<%= hidden_field('item','box', :value=>'#{@role[:method]}') %><%= link_box 'item', '#{@role[:method]}', :title=>nil %>"
      end
    else
      render :inline=>trans('role not valid')
    end
  end
  
  # remove a link given the link id 'id' and the item id 'item_id'
  def remove
    puts params.inspect
    @item = secure_drive(Item) { Item.find(params[:item_id]) }
    @link_id = params[:id]
    @item.remove_link(@link_id) && @item.save
  rescue ActiveRecord::RecordNotFound
    add_error'item not found'
  end
end
