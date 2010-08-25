module Zena
  module Remote
    class Node
      include Zena::Remote::Interface::InstanceMethods
      attr_accessor :connection, :attributes

      def initialize(connection, hash)
        @connection = connection
        @attributes = hash
      end

      def id
        @attributes['id']
      end

      def method_missing(method, *args)
        method = method.to_s
        if args.size == 1 && method =~ /(.*)=$/
          @attributes[$1] = args.first
        elsif args.size == 0
          if @attributes.has_key?(method)
            @attributes[method]
          else
            # build query
            if method.pluralize == method
              res = all(method)
            else
              res = first(method)
            end
          end
        else
          super
        end
      end
    end
  end # Remote
end # Zena