module Zena
  module Unit
    class TestCase < ActiveSupport::TestCase
      include Zena::Use::Fixtures
      include Zena::Use::TestHelper
      include Zena::Acts::Secure

      def self.helper_attr(*args)
        # Ignore since we include helpers in the TestCase itself
      end

      def setup
        login(:anon, 'zena')
      end

      def err(obj)
        obj.errors.each do |er,msg|
          puts "[#{er}] #{msg}"
        end
      end

    end
  end
end