module Zena
  module Use
    module Authlogic

      # def self.make_visitor(id)
      #   Thread.current[:visitor] = User.find(id)
      # end

      module Common

        def visitor
           Thread.current[:visitor]
         end

      end

      module ControllerMethods
        include Common

        private

          def set_visitor
            return Thread.current[:visitor] unless Thread.current[:visitor].nil?
            Thread.current[:visitor] = registred_visitor || anonymous_visitor
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
            @anonymous_visitor ||=  current_site.users.find_by_login_and_crypted_password(nil,nil).tap do |v|
                                      v.ip = request.headers['REMOTE_ADDR']
                                    end
          end

          def current_site
            host = request ? request.host : visitor.site.host
            @current_site ||= Site.find_by_host(host)
          end

          def check_is_admin
            render_404(ActiveRecord::RecordNotFound) unless visitor.is_admin?
            @admin = true
          end

          def lang
            visitor.lang
          end
      end

      module ViewMethods
        include Common
      end

    end
  end
end