module Zena
  module Use
    module Authentification
      module Common
        
        # Require a login for authenticated navigation (with '/oo' prefix) or for any content if the site's 'authorize'
        # attribute is true.
        def authorize
          return true if params[:controller] == 'session' && ['create', 'new', 'destroy'].include?(params[:action])

          # Require a login if :
          # 1. site forces authentication or navigation in '/oo'
          if (current_site.authentication? || params[:prefix] == AUTHENTICATED_PREFIX) && visitor.is_anon?
            return false unless do_login
          end
        end

        def do_login
          if current_site[:http_auth]
            session[:after_login_url] = request.parameters
            basic_auth_required do |username, password| 
              if user = User.make_visitor(:login => username, :password => password, :site => current_site)
                successful_login(user)
                return true
              end
            end
          else
            session[:after_login_url]   ||= request.parameters
            flash[:notice] = _("Please log in")
            redirect_to login_path and return false
          end
        end

        def successful_login(user)
          session[:user] = user[:id]
          session[:lang] = user.lang

          @visitor = user

          after_login_url = session[:after_login_url]
          session[:after_login_url] = nil
          if current_site[:http_auth] && params[:controller] != 'session'
            # no need to redirect
          else
            redirect_to after_login_url || user_path(visitor)
            return false
          end
        end
        
        # code adapted from Stuart Eccles from act_as_railsdav plugin
        def basic_auth_required(realm=current_site.name) 
          username, passwd = get_auth_data
          # check if authorized
          # try to get user
          if yield username, passwd
            true
          else
            # the user does not exist or the password was wrong
            headers["Status"] = "Unauthorized" 
            headers["WWW-Authenticate"] = "Basic realm=\"#{realm}\""

            # require login
            if current_site.authentication?
              render :nothing => true, :status => 401
            else
              redirect_url = session[:after_login_url] ? url_for(session[:after_login_url].merge(:prefix => session[:lang])) : '/'
              render :text => "
              <html>
                <head>
                <script type='text/javascript'>
                <!--
                window.location = '#{redirect_url}'
                //-->
                </script>
                </head>
                <body>redirecting to <a href='#{redirect_url}'>#{redirect_url}</a></body>
                </html>", :status => 401
            end
            false
          end 
        end
        
        # code from Stuart Eccles from act_as_railsdav plugin
        def get_auth_data 
          user, pass = '', '' 
          # extract authorisation credentials 
          if request.env.has_key? 'X-HTTP_AUTHORIZATION' 
            # try to get it where mod_rewrite might have put it 
            authdata = request.env['X-HTTP_AUTHORIZATION'].to_s.split 
          elsif request.env.has_key? 'HTTP_AUTHORIZATION' 
            # this is the regular location 
            authdata = request.env['HTTP_AUTHORIZATION'].to_s.split  
          end 

          # at the moment we only support basic authentication 
          if authdata and authdata[0] == 'Basic' 
            user, pass = Base64.decode64(authdata[1]).split(':')[0..1] 
          end 
          return [user, pass] 
        end
        
        # Restrict access some actions to administrators (used as a before_filter)
        def check_is_admin
          render_404(ActiveRecord::RecordNotFound) unless visitor.is_admin?
          @admin = true
        end
        
      end # Common

      module ControllerMethods
        include Common        
      end
      
      module ViewMethods
        include Common
      end
      
    end # Authentification
  end # Use
end # Zena