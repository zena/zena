ActionController::Routing::Routes.draw do |map|
  
  map.home       ':prefix',  :controller => 'nodes',    :action => 'index',  :prefix => /\w{0,2}/
  map.not_found '404.html',  :controller => 'nodes',    :action => 'not_found'
  map.login        'login',  :controller => 'session',  :action => 'new',    :requirements => { :method => :get  }
  map.logout      'logout',  :controller => 'session',  :action => 'destroy'
  
  map.resource  :session   # singleton resource
  map.resources :users, :member => { :preferences => :get }
  map.resources :groups
  
  map.connect ':prefix/*path', :controller => 'nodes', :action => 'show', :prefix => /\w\w/
  
  map.connect 'nodes/:node_id/versions/:id.:format', :controller => 'versions', :action => 'show' #, :requirements => { :method => :get }
  
  map.resources :nodes,                                           # FIXME: should be :put but it does not work
    :collection => { :search => :get,  :attribute => :get },      #   |
    :member =>     { :import => :post, :save_text => :put, :order => :any } do |nodes|
    nodes.resources :versions, 
                    :name_prefix => nil,
                    :member => { :edit    => :get,
                                 :propose => :put,
                                 :publish => :put,
                                 :unpublish => :put,
                                 :refuse  => :put,
                                 :remove  => :put,
                                 :preview => :put,
                                 :link    => :any }
                                 
    nodes.resources :discussions, :name_prefix => nil do |discussions|
      #discussions.resources :comments,
      #              :name_prefix => nil,
      #              :member => { :reply_to => :post }
    end
  end
  
  map.resources :documents, :member => { :crop_form => :get, :file_form => :get }
  # map.resources :trans_phrases do |phrases|
  #   phrases.resources :trans_values
  # end

  # FIXME monolingual
  
  #map.login  'login' , :controller=>'login', :action=>'login'
  #map.logout 'logout', :controller=>'login', :action=>'logout'
  #
  #map.not_found '404', :controller=>'main', :action=>'not_found'
  #
  #map.user_home "#{AUTHENTICATED_PREFIX}/home", :controller=>'user', :action=>'home', :prefix=>"#{AUTHENTICATED_PREFIX}"
  #
  #map.connect ':prefix', :controller => "main", :action=>'index', :prefix=>/^(#{AUTHENTICATED_PREFIX}|\w\w)$/
  #
  #map.connect 'data/:ext/:version_id/:filename', :controller=>'document', :action=>'data'
  #
  #map.search 'z/search', :controller=>'search', :action=>'find'
  #
  #if ZENA_ENV[:monolingual]
  #  map.connect '', :controller => "main", :action=>'index'
  #  map.default 'z/:controller/:action/:id'
  #  map.site_tree ':prefix/site_tree/:id', :controller=>'main', :action=>'site_tree', :prefix=>"#{AUTHENTICATED_PREFIX}"
  #  map.connect ":prefix/*path", :controller=>'main', :action=>'show', :prefix=>"#{AUTHENTICATED_PREFIX}"
  #  map.default 'z/:controller/:action/:id'
  #  map.site_tree 'site_tree/:id', :controller=>'main', :action=>'site_tree', :prefix=>''
  #  map.connect '*path', :controller=>'main', :action=>'show', :prefix=>''  
  #else
  #  map.site_tree ':prefix/site_tree/:id', :controller=>'main', :action=>'site_tree', :prefix=>/^(#{AUTHENTICATED_PREFIX}|\w\w)$/
  #  map.connect ':prefix/*path', :controller=>'main', :action=>'show', :prefix=>/^(#{AUTHENTICATED_PREFIX}|\w\w)$/
  #  map.default 'z/:controller/:action/:id'
  #  map.connect '*path', :controller=>'main', :action=>'show'
  #end
  ## 
  ## # Allow downloading Web Service WSDL as a file with an extension
  ## # instead of a file named 'wsdl'
  ## map.connect ':controller/service.wsdl', :action => 'wsdl'
  ## 
  ## # Install the default route as the lowest priority.
  
  # map.connect ':controller/:action/:id'
  
  # temporary routes...
  map.connect 'comments/:action/:id', :controller => 'comments'
  map.connect 'z/link/:action/:id', :controller => 'link'
  map.connect 'z/calendar/:action', :controller => 'calendar'
  map.connect 'z/link/:action', :controller => 'link'
  map.connect 'z/note/:action', :controller => 'note'
  map.redirect '/redirect', :controller => 'main', :action => 'redirect'
  
  # catch all
  #map.connect '*path',  :controller => 'nodes',    :action => 'not_found'
end
=begin
ActionController::Routing::Routes.draw do |map|
  # Add your own custom routes here.
  # The priority is based upon order of creation: first created -> highest priority.
  
  # Here's a sample route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # You can have the root of your site routed by hooking up '' 
  # -- just remember to delete public/index.html.
  
end
=end