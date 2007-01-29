class SearchController < ApplicationController
  
  #TODO: finish test for '[project], [note], nodes...'
  def find
    if params[:search] && params[:search] != ''
      @phrase = params[:search]
      @phrase = "#{@phrase}%" unless @phrase[-1..-1] == '%'
      @result_pages = nil
      @results = nil
      secure(Node) do
        @result_pages, @results = paginate :nodes, :conditions=>["id = ? OR type = ? OR name LIKE ?",params[:search],params[:search],@phrase], :order => "name ASC", :per_page => 15
        @results # important: this is the 'secure' yield return, it is used to secure found nodes
      end
    else
      @phrase = 'children'
      @results = secure(Page) { Page.find(:all, :conditions=>["parent_id = ?",params[:id]], :limit=>5)}
    end  
    render :partial=>'search/results', :locals=>{:results =>@results}
  end
  
end
