module Zena
  module View
    class TestCase < ActionView::TestCase
      include Zena::Use::Fixtures
      include Zena::Use::TestHelper
      include Zena::Acts::Secure
      include ::Authlogic::TestCase

      setup :activate_authlogic

      def setup
        login :anon
      end

      def assert_css(match, target)
        target = Hpricot(target)
        assert !target.search(match).empty?,
          "expected tag, but no tag found matching #{match.inspect} in:\n#{target.inspect}"
      end

      def self.helper_attr(*args)
        # Ignore since we include helpers in the TestCase itself
      end

    end
  end
end