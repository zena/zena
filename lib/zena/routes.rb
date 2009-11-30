module Zena
  module Routes
    def zen_routes
      home       ':prefix',  :controller => 'nodes',    :action => 'index',  :prefix => /[a-zA-Z]{0,2}/
      not_found  ':prefix/404.html',  :controller => 'nodes',    :action => 'not_found', :prefix => /\w\w/
      login      'login',  :controller => 'user_sessions',  :action => 'new',    :requirements => { :method => :get  }
      logout     'logout',  :controller => 'user_sessions',  :action => 'destroy'

      upload_progress 'upload_progress', :controller => 'documents', :action => 'upload_progress'

      resource  :session, :controller => "user_sessions"   # singleton resource
      resources :pings
      resources :users, :member => { :preferences => :get, :swap_dev => :get }
      resources :groups
      resources :iformats

      connect ':prefix/*path?:cachestamp',  :controller => 'nodes', :action => 'show', :prefix => /\w\w/, :cachestamp => /\d+/
      connect ':prefix/*path',  :controller => 'nodes', :action => 'show', :prefix => /\w\w/
      connect 'dav/*path_info', :controller => 'nodes', :action => 'webdav'

      resources :nodes,
        :collection => { :asearch => :get, :search => :get },
        :member =>     { :import => :post, :export => :get, :save_text => :put,
                         :order => :any, :clear_order => :any,
                         :zafu => :get, :drop => :put, :attribute => :get
                       }.merge(Zena::Use::Grid::Routes) do |nodes|
        nodes.resources :versions,
                        :member => { :edit    => :get,
                                     :diff    => :get,
                                     :custom_tab => :get,
                                     :propose => :put,
                                     :publish => :put,
                                     :unpublish => :put,
                                     :refuse  => :put,
                                     :remove  => :put,
                                     :redit   => :put,
                                     :preview => :get,
                                     :link    => :any }

        nodes.resources :links

        #nodes.resources :discussions, :name_prefix => nil do |discussions|
        #  #discussions.resources :comments,
        #  #              :name_prefix => nil,
        #  #              :member => { :reply_to => :post }
        #end

      end

      # FIXME: merge 'documents' controller into 'nodes' (keep module for clarity)
      resources :documents, :collection => { :upload    => :post, :get_uf => :get },
                                :member     => { :crop_form => :get }

      resources :relations
      resources :virtual_classes
      resources :sites,
        :member     => { :clear_cache => :post }
      resources :comments,
                    :collection => { :empty_bin => :delete },
                    :member => { :remove  => :put,
                                 :publish => :put,
                                 :reply_to => :post,
                               }
      resources :data_entries, :member => { :zafu => :get }

      # temporary routes...
      connect 'discussions/:action/:id', :controller => 'discussions'

      # catch all
      connect '*path',  :controller => 'nodes',    :action => 'catch_all'
    end
  end # Routes
end # Zena