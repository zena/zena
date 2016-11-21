require 'httmultiparty'

module Zena
  module Remote
    class Connection
      def initialize
      end

      # Return a sub-class of Zena::Remote::Connection with the specified connection tokens built in.
      # We create a new class because HTTParty works this way (class globals).
      def self.connect(uri, token)
        Class.new(self) do
          include HTTMultiParty
          extend Zena::Remote::Interface::ConnectionMethods

          class << self
            alias http_delete delete
            alias delete destroy
          end

          @found_classes = {}
          @uri = uri
          @message_logger = STDOUT

          def self.[](class_name)
            @found_classes[class_name] ||= Zena::Remote::Klass.new(self, class_name)
          end

          def self.logger
            @logger ||= default_logger
          end

          def self.log_message(msg)
            logger = @message_logger || self.logger
            if logger.respond_to?(:info,true)
              logger.info "-\n"
              logger.info "  %-10s: %s" % ['operation', 'message']
              logger.info "  %-10s: %s" % ['message', msg.inspect]
            else
              @message_logger.send(:puts, msg)
            end
          end

          def self.message_logger=(logger)
            @message_logger = logger
          end

          def self.default_logger
            host = URI.parse(@uri =~ %r{^\w+://} ? @uri : "http://#{@uri}").host
            log_path = "log/#{host}.log"
            dir = File.dirname(log_path)
            Dir.mkdir(dir) unless File.exist?(dir)
            Logger.new(File.open(log_path, 'ab'))
          end

          def self.logger=(logger)
            @logger = logger
          end

          headers 'Accept' => 'application/xml'
          headers 'HTTP_X_AUTHENTICATION_TOKEN' => token
          base_uri uri
        end
      end
    end
  end # Remote
end # Zena