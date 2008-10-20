ActionController::Routing::Routes.draw do |map|
  
  map.home       ':prefix',  :controller => 'nodes',    :action => 'index',  :prefix => /[a-zA-Z]{0,2}/
  map.not_found  ':prefix/404.html',  :controller => 'nodes',    :action => 'not_found', :prefix => /\w\w/
  map.login      'login',  :controller => 'session',  :action => 'new',    :requirements => { :method => :get  }
  map.logout     'logout',  :controller => 'session',  :action => 'destroy'
  
  map.resource  :session   # singleton resource
  map.resources :users, :member => { :preferences => :get, :swap_dev => :get }
  map.resources :groups
  map.resources :iformats
  
  map.connect ':prefix/*path',  :controller => 'nodes', :action => 'show', :prefix => /\w\w/
  map.connect 'dav/*path_info', :controller => 'nodes', :action => 'webdav'
  
  map.connect 'nodes/:node_id/versions/:id.:format', :controller => 'versions', :action => 'show' #, :requirements => { :method => :get }
  
  map.resources :nodes,
    :collection => { :asearch => :get, :search => :get },
    :member =>     { :import => :post, :export => :get, :save_text => :put,
                     :order => :any, :clear_order => :any,
                     :zafu => :get, :drop => :put, :attribute => :get } do |nodes|
    nodes.resources :versions, 
                    :name_prefix => nil,
                    :member => { :edit    => :get,
                                 :custom_tab => :get,
                                 :propose => :put,
                                 :publish => :put,
                                 :unpublish => :put,
                                 :refuse  => :put,
                                 :remove  => :put,
                                 :redit   => :put,
                                 :preview => :put,
                                 :link    => :any,
                                 :destroy_version => :put } # FIXME: should be a DELETE
    
    nodes.resources :links
    
    #nodes.resources :discussions, :name_prefix => nil do |discussions|
    #  #discussions.resources :comments,
    #  #              :name_prefix => nil,
    #  #              :member => { :reply_to => :post }
    #end
    
  end
  
  # FIXME: merge 'documents' controller into 'nodes' (keep module for clarity)
  map.resources :documents, :collection => { :upload    => :post, :upload_progress => :post }, 
                            :member     => { :crop_form => :get,  :file_form       => :get  }
  
  map.resources :relations
  map.resources :virtual_classes
  map.resources :sites,
    :collection => { :zena_up => :get },
    :member     => { :clear_cache => :post }
  map.resources :comments,
                :collection => { :empty_bin => :delete },
                :member => { :remove  => :put,
                             :publish => :put,
                             :reply_to => :post,
                           }
  map.resources :data_entries, :member => { :zafu => :get }

  # temporary routes...
  map.connect 'discussions/:action/:id', :controller => 'discussions'
  
  # catch all
  map.connect '*path',  :controller => 'nodes',    :action => 'catch_all'
end
