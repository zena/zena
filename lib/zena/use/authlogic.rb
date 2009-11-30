module Zena
  module Use
    module Authlogic
      module Common

        def visitor
           Thread.current[:visitor]
         end

      end # Common

      module ControllerMethods

        include Common

        private

          def set_visitor
            return Thread.current[:visitor] unless Thread.current[:visitor].nil?
            Thread.current[:visitor] =  registred_visitor || http_visitor || token_visitor || anonymous_visitor
          end

          def set_site
            return Thread.current[:site] unless Thread.current[:site].nil?
            Thread.current[:site] = Site.find_by_host(request.host)
          end

          def set_after_login
            Thread.current[:after_login_url] = request.parameters
          end

          def registred_visitor
            visitor_session && visitor_session.user
          end

          def visitor_session
            UserSession.find
          end

          def anonymous_visitor
            @anonymous_visitor ||=  User.find_anonymous(current_site.id).tap do |v|
                                      v.ip = request.headers['REMOTE_ADDR']
                                    end
          end

          def current_site
            Thread.current[:site]
          end

          def check_is_admin
            render_404(ActiveRecord::RecordNotFound) unless visitor.is_admin?
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

          def http_visitor
            if current_site.http_auth && request.format == Mime::XML
              authenticate_or_request_with_http_basic do |login, password|
                User.authenticate(login, password, current_site.id)
              end
            end
          end

          def force_authentication?
            if current_site.authentication? && visitor.is_anon?
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