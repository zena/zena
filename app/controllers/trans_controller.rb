class TransController < ApplicationController
  before_filter :check_translator, :except=>[:lang_menu]

  def edit
    @trans = TransKey.find(params[:id])
    @trans.lang = lang
    render(:layout=>false)
  end

  def update
    @trans = TransKey.find(params[:id])
    @trans.lang = lang
    @trans.value = params[:trans][:value]
    @trans.save
    render(:inline=>"<%= trans @trans[:key] %>")
  end
  
  def lang_menu
  end

  private
  def check_translator
    page_not_found unless user_groups.include?(ZENA_ENV[:translate_group])
  end
end
