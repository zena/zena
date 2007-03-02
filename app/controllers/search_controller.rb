class SearchController < ApplicationController
  
  #TODO: finish test for '[project], [note], nodes...'
  def find
    if params[:search] && params[:search] != ''
      @phrase = params[:search]
      @phrase = "#{@phrase}%" unless @phrase[-1..-1] == '%'
      conditions = ["id = ? OR type = ? OR name LIKE ?",params[:search],params[:search],@phrase]
    elsif params[:id]
      @phrase = 'children'
      conditions = ["parent_id = ? AND kpath LIKE 'NP%'",params[:id]]
    else
      # error
      raise Exception.new('bad arguments for search ("search" field missing)')
    end
    @result_pages = nil
    @results = nil
    secure(Node) do
      @result_pages, @results = paginate :nodes, :conditions=>conditions, :order => "name ASC", :per_page => 15
      @results # important: this is the 'secure' yield return, it is used to secure found nodes
    end
    render :partial=>'search/results', :locals=>{:results =>@results}
  end
  
end
