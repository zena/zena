require 'HTTParty'

module Zena
  module Remote
    module Operator
      def find(count, query)
        if query.kind_of?(String)
          # Consider string as query builder
          query = {:qb => query, :_find => count}
        else
          query = query.merge(:_find => count)
        end

        case count
        when :first
          if result = get('/nodes/search', :query => query)['nodes']
            build_record(result.first)
          else
            nil
          end
        when :all
          if result = get('/nodes/search', :query => query)['nodes']
            result.map do |hash|
              build_record(hash)
            end
          else
            nil
          end
        when :count
          if result = get('/nodes/search', :query => query)['count']
            result
          else
            nil
          end
        else
          raise Exception.new("Invalid count should be :all, :first or :count (found #{count.inspect})")
        end
      end

      private
        def build_record(hash)
          Zena::Remote::Node.new(self, hash)
        end
    end

    class Connection

      # Return a sub-class of Zena::Remote::Connection with the specified connection tokens built in.
      def self.connect(uri, token)
        Class.new(self) do
          include HTTParty
          extend Operator

          headers 'Accept' => 'application/xml'
          headers 'HTTP_X_AUTHENTICATION_TOKEN' => token
          base_uri uri
        end
      end
    end
  end # Remote
end # Zena