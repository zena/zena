module Zena
  module Remote
    class Node
      include Zena::Remote::Interface::InstanceMethods
      attr_accessor :connection, :attributes, :errors

      def initialize(connection, hash)
        @connection = connection
        @attributes = {}
        self.attributes = hash
      end

      def attributes=(new_attributes)
        raise Exception.new("Invalid attributes. Expecting a hash, found #{new_attributes.inspect}") unless new_attributes.kind_of?(Hash)
        new_attributes.stringify_keys.each do |key, value|
          writer = "#{key}=".to_sym
          if self.respond_to?(writer)
            self.send(writer, value)
          elsif value.kind_of?(Array)
            # setting multiple ids
            key = "#{key}_ids" unless key =~ /_ids$/
            @attributes[key] = value.map do |elem|
              if elem.kind_of?(Remote::Node)
                elem.id
              else
                elem
              end
            end
          elsif value.kind_of?(Remote::Node)
            key = "#{key}_id" unless key =~ /_id$/
            @attributes[key] = value.id
          elsif key =~ /_ids$/ && value.kind_of?(String)
            @attributes[key] = value.split(',').map(&:to_i)
          else
            @attributes[key] = value
          end
        end
      end

      def tag_names=(list)
        @attributes['tag_names'] = SerializableArray.new('tag_names', 'tag', list)
      end

      def id
        @attributes['id']
      end

      def method_missing(method, *args)
        method = method.to_s
        if args.size == 1 && method =~ /(.*)=$/
          key = $1
          elem = args.first
          if elem.kind_of?(Remote::Node)
            key = "#{key}_id" unless key =~ /_ids?$/
            @attributes[key] = elem.id
          elsif elem.kind_of?(Array)
            key = "#{key}_ids" unless key =~ /_ids?$/
            if elem == []
              # Fix for strange handling of empty array by to_xml and such.
              @attributes[key] = nil
            else
              @attributes[key] = elem.map do |value|
                value.kind_of?(Remote::Node) ? value.id : value
              end
            end
          else
            @attributes[$1] = elem
          end
        elsif args.size == 0
          if @attributes.has_key?(method)
            @attributes[method]
          elsif method =~ /_ids?$/
            @attributes[method] ||= []
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