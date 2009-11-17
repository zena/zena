module Zena
  module Controller
    class TestCase < ActionController::TestCase
      include Zena::Use::Fixtures
      include Zena::Use::TestHelper
      include Zena::Acts::Secure
      include ::Authlogic::TestCase

      def setup
        activate_authlogic
        login(:anon)
      end

      def assert_css(match)
        target = Hpricot(@response.body)
        assert !target.search(match).empty?,
          "expected tag, but no tag found matching #{match.inspect} in:\n#{target.inspect}"
      end

      def err(obj)
        obj.errors.each_error do |er,msg|
          puts "[#{er}] #{msg}"
        end
      end
    end
  end
end