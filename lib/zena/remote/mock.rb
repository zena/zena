module Zena
  module Remote
    module Mock
      class Http
        def initialize(options)
          @options = options
        end

        def request(raw_request)
          # body should contain xml data for post and put (@raw_request.body ?)
          method  = raw_request.method.downcase
          path    = raw_request.path
          body    = raw_request.body

          response = $test_connection.test_request(method, path, body, @options[:headers], false)
          transform_response(response)
        end

        # Transform an ActionController::Response into a Net::HTTP response.
        # Based on code from fakeweb (thanks Chrisk !)
        def transform_response(ac_res)
          code, msg = 200, 'OK'
          response = Net::HTTPResponse.send(:response_class, code.to_s).new("1.0", code.to_s, msg)
          response.instance_variable_set(:@body, ac_res.body)
          ac_res.headers.each do |name, value|
            if value.respond_to?(:each)
              value.each { |v| response.add_field(name, v) }
            else
              response[name] = value
            end
          end

          response.instance_variable_set(:@read, true)

          class << response
            def read_body(*args, &block)
              yield @body if block_given?
              @body
            end
          end

          response
        end
      end

      # Redirect actual request to the integration test.
      class Request < HTTParty::Request
        def http
          Mock::Http.new(options)
        end
      end

      # Include this module to mock the connection and use the integration test to execute
      # the actual request operations.
      module Connection

        def self.included(base)
          def base.perform_request(http_method, path, options) #:nodoc:
            options = default_options.dup.merge(options)
            process_cookies(options)
            request = Zena::Remote::Mock::Request.new(http_method, path, options).perform
          end
        end
      end # Connection
    end # Mock
  end # Remote
end # Zena