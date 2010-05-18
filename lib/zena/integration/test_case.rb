module Zena
  module Integration
    class MockConnection < ActiveResource::Connection
      def initialize(test, site = 'http://test.host')
        @test = test
        super site
      end

      def logger
        Page.logger
      end

      # Mock request to remote service by doing a call to the integration test.
      def request(method, path, *arguments)
        case method
        when :get, :delete, :head
          headers = arguments.first
          params  = {}
        else
          headers = arguments.last
          # The params here contain an xml string representing the request body.
          params  = arguments.first
        end
        logger.info "#{method.to_s.upcase} #{site.scheme}://#{site.host}#{path} (#{arguments.last.inspect})" if logger
        result = nil
        ms = Benchmark.ms do
          @test.send(method, "#{site.scheme}://#{site.host}#{path}", params, headers)
          result = @test.response
        end
        logger.info "--> %d %s (%d %.0fms)" % [result.code, result.message, result.body ? result.body.length : 0, ms] if logger
        handle_response(result)
      rescue Timeout::Error => e
        raise TimeoutError.new(e.message)
      end
    end # MockConnection


    class TestCase < ActionController::IntegrationTest
      include Zena::Use::Fixtures

      def init_test_connection!
        $test_connection = MockConnection.new(self)
      end
    end # TestCase

    module MockResource
      def self.included(base)
        base.class_eval do
          def self.connection(*args)
            $test_connection.tap do |conn|
              conn.site     = self.site
              conn.password = self.password
              conn.user     = self.user
            end
          end
        end
      end
    end # MockResource
  end # Integration
end # Zena