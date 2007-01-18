class SearchController < ApplicationController
  
  #TODO: finish test for '[project], [note], nodes...'
  def find_in_edit
    if params[:search] && params[:search] != ''
      if params[:search][0..0] == '='
        @phrase = params[:search][1..-1].gsub(/[^a-zA-Z0-9_\-]/,'')
        # FIXME: SECURITY is there a better way to do this ?
        begin
          klass = eval @phrase.capitalize
          @phrase = @phrase.pluralize
          raise NameError unless klass.ancestors.include?(Node)
          @results = secure(klass) { klass.find(:all) }
        rescue NameError
          @results = []
        end
      else
        @phrase = params[:search]
        @phrase = "#{@phrase}%" unless @phrase[-1..-1] == '%'
        @results = secure(Node) { Node.find(:all, :conditions=>["name LIKE ?",@phrase], :limit=>5)}
      end
      render :partial=>'search/find_in_edit', :locals=>{:results =>@results}
    else
      @phrase = 'children'
      @results = secure(Page) { Page.find(:all, :conditions=>["parent_id = ?",params[:id]], :limit=>5)}
      render :partial=>'search/find_in_edit', :locals=>{:results =>@results}
    end
  end
  
end
