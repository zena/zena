module Zena
  module Use
    module Authlogic
      class RenderSession < ActiveRecord::Base
        set_table_name :sessions
      end

      module Common

        def visitor
           Thread.current[:visitor]
         end

      end # Common

      module ControllerMethods

        def self.included(base)
          base.before_filter :set_visitor, :force_authentication?, :redirect_to_https
        end

        include Common
        
        def ssl_request?
          request.ssl? || request.headers['X_FORWARDED_PROTO'] == 'https'
        end

        private

          def save_after_login_path
            # prevent redirect to favicon or css
            return unless request.format == Mime::HTML
            path = params[:path]
            if path && path.last =~ /\.(.+)\Z/
              return if $1 != 'html'
            end

            session[:after_login_path] = request.parameters
          end

          def set_visitor
            unless site = forge_cookie_with_http_auth || Site.find_by_host(request.host)
              raise ActiveRecord::RecordNotFound.new("host not found #{request.host}")
            end

            # We temporarily set the locale so that any error message raised during authentification can be properly shown
            ::I18n.locale = site.default_lang

            User.send(:with_scope, :find => {:conditions => ['site_id = ?', site.id]}) do
              Thread.current[:visitor] = token_visitor || registered_visitor || anonymous_visitor(site)
            end
          end

          # Secured in site with scope in set_visitor
          def registered_visitor
            visitor_session && visitor_session.user
          end

          def visitor_session
            UserSession.find
          end

          def anonymous_visitor(site)
            site.anon.tap do |v|
              v.ip = request.headers['REMOTE_ADDR']
            end
          end

          def check_is_admin
            raise ActiveRecord::RecordNotFound unless visitor.is_admin?
            @admin = true
          end

          def lang
            visitor.lang
          end

          # Secured in site with scope in set_visitor
          def token_visitor
            if user_token = (request.headers['HTTP_X_AUTHENTICATION_TOKEN'] || params[:user_token])
              User.find_by_single_access_token(user_token)
            end
          end

          # Create a fake cookie based on HTTP_AUTH using session_id and render_token. This is
          # only used for requests to localhost.
          def forge_cookie_with_http_auth
            if (request.host == '127.0.0.1' || request.host == 'localhost') && request.port == Zena::ASSET_PORT
              authenticate_with_http_basic do |login, password|
                # login    = visitor.id
                # password = persistence_token

                # Temporary user to find site
                user = User.find(login)
                if user && site = user.site
                  # OK, we can set host
                  request.env['HTTP_HOST'] = "#{site.host}:#{Zena::ASSET_PORT}"
                  # forge cookie
                  cookies['user_credentials'] = "#{password}::#{login}"
                  site
                else
                  raise ActiveRecord::RecordNotFound
                end
              end
            else
              nil
            end
          end

          # Secured in site with scope in set_visitor
          def http_visitor(site)
            if request.format == Mime::XML
              # user must be an authentication token
              authenticate_or_request_with_http_basic do |login, password|
                User.find_by_single_access_token(password)
              end
            elsif site.http_auth # HTTP_AUTH disabled for now.
              user = User.find_allowed_user_by_login(login)
              user if (user && user.valid_password?(password))
            end
          end

          def force_authentication?
            if visitor.is_anon?
              # Anonymous visitor has more limited access rights.

              if current_site.authentication? || params[:prefix] == AUTHENTICATED_PREFIX
                # Ask for login
                save_after_login_path
                redirect_to login_path
              elsif request.format == Mime::XML && (self != NodesController || !params[:prefix])
                # Allow xml without :prefix in NodesController because it is rendered with zafu.

                # Authentication token required for xml.
                render :xml => [{:message => 'Authentication token needed.'}].to_xml(:root => 'errors'), :status => 401
              end
            end
          end
          
          # Force https if ssl_on_auth is enabled. This method is overwriten in UserSessionsController.
          def redirect_to_https
            if current_site.ssl_on_auth
              if !ssl_request? && !visitor.is_anon? && !local_request?
                redirect_to :protocol => "https://" 
              elsif ssl_request? && visitor.is_anon?
                redirect_to :protocol => "http://" 
              end
            end
          end
      end

      module ViewMethods

        include Common

      end # ViewMethods

    end # Authlogic
  end # Use
end # Zena