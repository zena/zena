=begin
The MainController is a navigation controller. No operation is done here: the web controller just selects
the information that will appear on the different pages or asks other controllers to do part of the job
for him.
=end
class MainController < ApplicationController
  before_filter :check_url, :except => [:not_found, :redirect]
  
  def index
    # show home page
    @item = secure(Item) { Item.find(ZENA_ENV[:root_id]) }
    render_and_cache 'index'
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  def show
    @item = Page.find_by_path(user_id, user_groups, lang, params[:path])
    render_and_cache
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  # Page not found
  def not_found
    render_and_cache 'not_found'
  end
  
  def redirect
    req = request.parameters
    req[:action] = 'show'
    req[:prefix] = prefix
    redirect_to req
  end
  
  private
  
  # do not accept a logged in user to browse as if he was anonymous
  def check_url
    if session[:user] && params[:prefix] != AUTHENTICATED_PREFIX
      req = request.parameters
      req[:prefix] = AUTHENTICATED_PREFIX
      redirect_to req
    end
  end
  
  # tested to here
end