class TransController < ApplicationController
  before_filter :check_translator
  helper MainHelper
  layout 'admin'

  def edit
    @trans = TransPhrase.find(params[:id])
    @trans.lang = lang
    render(:layout=>false)
  end

  def update
    @trans = TransPhrase.find(params[:id])
    @trans.lang = lang
    @trans.value = params[:trans][:value]
    @trans.save
    render(:inline=>"<%= trans(@trans[:phrase], :translate=>true) %>")
  end
  
  # TODO: test
  def list
    @keyword_pages, @keywords =
            paginate :trans_phrases, :select=>"trans_phrases.*, trans_values.value AS value, (trans_values IS NULL) as no_value, trans_values.lang AS lang", :join=>"LEFT JOIN trans_values ON trans_values.phrase_id = trans_phrases.id AND trans_values.lang = '#{lang.gsub(/[^\w]/,'')}'", :order => "no_value DESC, phrase ASC", :per_page => 30
  end
  
  # TODO: test
  def new
    render :layout=>false
  end
  
  # TODO: test
  def create
    session[:translate] = 1
    @trans = TransKey.translate(params[:trans][:phrase])
    render :partial=>'trans/li', :collection=>[@trans]
  end
  
  # TODO: test
  def remove
    puts params.inspect
    if @phrase_id = params[:phrase_id]
      obj = TransPhrase.find(@phrase_id)
      obj.destroy
    else
      obj = TransValue.find(params[:value_id])
      @phrase_id = obj[:phrase_id]
      obj.destroy
      @trans = TransPhrase.find(@phrase_id)
    end
  end
  
  private
  def check_translator
    page_not_found unless visitor_groups.include?(ZENA_ENV[:translate_group])
  end
end
