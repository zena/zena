class GroupController < ApplicationController
  before_filter :check_is_admin, :except=>[:home]
  helper MainHelper
  layout 'admin'
  
  def edit
    redirect_to :action=>'list' if 1 == params[:id]
    @group = Group.find(params[:id])
    render :action=>'list'
  end
end
