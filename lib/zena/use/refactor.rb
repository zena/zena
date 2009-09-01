module Zena
  module Use
    module Refactor
      module Common
        
        # TODO: test
        def visitor
          @visitor ||= returning(User.make_visitor(:host => request.host, :id => session[:user])) do |user|
            if session[:user] != user[:id]
              # changed user (login/logout)
              session[:user] = user[:id]
            end
            if user.is_anon?
              user.ip = request.headers['REMOTE_ADDR']
            end
          end
        end

        # TODO: test
        def lang
          visitor.lang
        end        
        
        # Read the parameters and add errors to the object if it is considered spam. Save it otherwize.
        def save_if_not_spam(obj, params)
          # do nothing (overwritten by plugins like zena_captcha)
          obj.save
        end
        
        
        
      end # Common

      module ControllerMethods
        include Common        
      end
      
      module ViewMethods
        include Common
      end
      
    end # Refactor
  end # Use
end # Zena