module Zena
  module Remote
    class Node
      attr_accessor :connection, :attributes

      def initialize(connection, hash)
        @connection = connection
        @attributes = hash
      end

      def method_missing(method, *args)
        if args.size == 1 && method.to_s =~ /(.*)=$/
          @attributes[$1] = args.first
        elsif args.size == 0
          @attributes[method.to_s]
        else
          super
        end
      end
    end
  end # Remote
end # Zena