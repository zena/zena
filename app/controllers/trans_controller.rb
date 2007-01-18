class TransController < ApplicationController
  before_filter :check_translator, :except=>[:lang_menu]
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
    render(:inline=>"<%= trans @trans[:phrase] %>")
  end
  
  def lang_menu
  end
  
  # TODO: test
  def list
    @keyword_pages, @keywords =
            paginate :trans_phrases, :order => "'phrase'", :per_page => 20
  end

  private
  def check_translator
    page_not_found unless visitor_groups.include?(ZENA_ENV[:translate_group])
  end
end
