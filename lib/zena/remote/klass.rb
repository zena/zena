module Zena
  module Remote
    class Klass
      attr_accessor :connection, :name

      include Zena::Remote::Interface::ClassMethods

      def initialize(connection, name)
        @connection = connection
        @name = name
      end
    end
  end # Remote
end # Zena