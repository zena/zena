module Zena
  module Controller
    class TestCase < ActionController::TestCase
      include Zena::Use::Fixtures
      include Zena::Use::TestHelper
      include Zena::Acts::Secure

      def logout
        reset_session
      end

      alias login_without_controller login

      def login(*args)
        login_without_controller(*args)
        @controller.instance_eval { @visitor = Thread.current.visitor }
      end

      def err(obj)
        obj.errors.each do |er,msg|
          puts "[#{er}] #{msg}"
        end
      end
    end
  end
end