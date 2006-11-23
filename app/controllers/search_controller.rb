class SearchController < ApplicationController
  
  def find_in_edit
    if params[:search] && params[:search] != ''
      @phrase = params[:search]
      @phrase = "#{@phrase}%" unless @phrase[-1..-1] == '%'
      @results = secure(Item) { Item.find(:all, :conditions=>["name LIKE ?",@phrase])}
      render :partial=>'search/find_in_edit', :locals=>{:results =>@results}
    else
      @phrase = 'children'
      @item = secure(Item) { Item.find(params[:id]) }
      @results = @item.children
      render :partial=>'search/find_in_edit', :locals=>{:results =>@results}
    end
  end
  
end
