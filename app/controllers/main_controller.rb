=begin
FIXME: merge what this controller does somewhere else and remove.
=end
class MainController < ApplicationController
  before_filter :check_url, :except => [:not_found, :redirect]
  
  def index
    # show home page
    render_and_cache 'index'
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  def test
    render :inline=>@request.host
  end
  
  # TODO: test new path, test wrong node.site == visitor.site
  def show
    path = params[:path].dup
    if path.last =~ /[a-zA-Z\-_]+([0-9]+)(\.|$)/
      path.pop
      basepath = path.join('/')
      @node = secure!(Node) { Node.find_by_zip($1.to_i) }
    else
      @node = secure!(Node) { Node.find_by_path(path.join('/')) }
      basepath = path.join('/')
    end
    if basepath == @node.basepath(true)
      render_and_cache
    else
      redirect_to zen_path(@node)
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  # Page not found
  def not_found
    render_and_cache 'not_found'
  end
  
  # TODO: test
  def site_tree
    @node = secure!(Node) { Node.find(params[:id]) }
    render
    if !session[:user]
      cache_page
    end
  end
  
  # Used to prevent Safari not reloading bug
  def redirect
    [:notice, :error].each do |sym|
      if session[sym]
        flash[sym] = session[sym] 
        session[sym] = nil
      end
    end
    redirect_to params[:url]
  end
  
  def select_prefix
    redirect_with_prefix
  end

  private
  
  def redirect_with_prefix
    req = request.parameters
    req[:prefix] = prefix
    req[:action] = 'index' if req[:action] == 'select_prefix'
    redirect_to req
  end
  
  # do not accept a logged in user to browse as if he was anonymous
  def check_url
    if (params[:action] == 'show' && (!params[:path].kind_of?(Array) || params[:path] == []))
      redirect_to :action=>'index', :prefix=>prefix
    elsif !params[:prefix] || (!visitor.is_anon? && params[:prefix] != AUTHENTICATED_PREFIX)
      redirect_with_prefix
    end
  end
  
  # tested to here
end