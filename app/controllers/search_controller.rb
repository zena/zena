class SearchController < ApplicationController
  
  def find_in_edit
    @phrase = params[:for]
    @phrase = "#{@phrase}%" unless @phrase[-1..-1] == '%'
    @results = secure(Item) { Item.find(:all, :conditions=>["name LIKE ?",@phrase])}
  end
  
end
