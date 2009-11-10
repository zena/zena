module Zena
  module Unit
    class TestCase < ActiveSupport::TestCase
      include Zena::Use::Fixtures
      include Zena::Use::TestHelper
      include Zena::Acts::Secure
      include ::Authlogic::TestCase

      setup :activate_authlogic

      def setup
        #log anonymously by default
        login(:anon)
      end

      def self.helper_attr(*args)
        # Ignore since we include helpers in the TestCase itself
      end

    end
  end
end