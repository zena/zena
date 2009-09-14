require 'hpricot'

module Zena
  module View
    class TestCase < ActionView::TestCase
      include Zena::Use::Fixtures
      include Zena::Use::TestHelper
      include Zena::Acts::Secure
      
      def self.helper_attr(*args)
        # Ignore since we include helpers in the TestCase itself
      end
      
      def setup
        login(:anon, 'zena')
      end
      
      def assert_css(match, target)
        target = Hpricot(target)
        assert !target.search(match).empty?, 
          "expected tag, but no tag found matching #{match.inspect} in:\n#{target.inspect}"
      end
    end
  end
end