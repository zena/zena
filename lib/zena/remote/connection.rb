require 'HTTParty'

module Zena
  module Remote
    class Connection

      # Return a sub-class of Zena::Remote::Connection with the specified connection tokens built in.
      def self.connect(uri, token)
        Class.new(self) do
          include HTTParty
          extend Zena::Remote::Interface::ClassMethods

          headers 'Accept' => 'application/xml'
          headers 'HTTP_X_AUTHENTICATION_TOKEN' => token
          base_uri uri
        end
      end
    end
  end # Remote
end # Zena