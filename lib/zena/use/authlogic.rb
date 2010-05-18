module Zena
  module Use
    module Authlogic
      module Common

        def visitor
           Thread.current[:visitor]
         end

      end # Common

      module ControllerMethods

        def self.included(base)
          base.before_filter :set_visitor, :force_authentication?
        end

        include Common

        private

          def save_after_login_url
            session[:after_login_url] = request.parameters
          end

          def set_visitor
            unless site = Site.find_by_host(request.host)
              raise ActiveRecord::RecordNotFound.new("host not found #{request.host}")
            end

            # We temporarily set the locale so that any error message raised during authentification can be properly shown
            ::I18n.locale = site.default_lang

            User.send(:with_scope, :find => {:conditions => ['site_id = ?', site.id]}) do
              Thread.current[:visitor] = registered_visitor || http_visitor(site) || token_visitor || anonymous_visitor(site)
            end
          end

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

          def token_visitor
            if user_token = params[:user_token] && request.format == Mime::XML
              User.find_by_single_access_token(user_token)
            end
          end

          def http_visitor(site)
            if site.http_auth && request.format == Mime::XML
              authenticate_or_request_with_http_basic do |login, password|
                user = User.find_allowed_user_by_login(login)
                user if (user && user.valid_password?(password))
              end
            end
          end

          def force_authentication?
            if (current_site.authentication? || params[:prefix] == AUTHENTICATED_PREFIX) && visitor.is_anon?
              save_after_login_url
              redirect_to login_url
            end
          end

      end

      module ViewMethods

        include Common

      end # ViewMethods

    end # Authlogic
  end # Use
end # Zena