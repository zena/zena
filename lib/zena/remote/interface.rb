module Zena
  module Remote
    module Interface

      # Methods to retrieve remote nodes.
      module Read
        # Used by @connection.find(...)
        module Collection
          def find_url
            "/nodes/search"
          end
        end

        # Used by instance.find(...)
        module Instance
          def find_url
            "/nodes/#{id}/find"
          end

          def get(*args)
            @connection.get(*args)
          end
        end

        # Find remote nodes with query builder or indexed search
        def find(count, query = nil, options = {})
          if query.nil?
            query = count
            count = query.kind_of?(Fixnum) ? :find : :all
          end

          if query.kind_of?(String)
            # Consider string as query builder
            result = get(find_url, :query => options.merge(:qb => query, :_find => count))

          elsif query.kind_of?(Fixnum)
            result = get("/nodes/#{query}")
            if node = result['node']
              result = {'nodes' => [node]}
            end

          else
            result = get(find_url, :query => query.merge(options).merge(:_find => count))
          end

          case count
          when :first
            if nodes = result['nodes']
              build_record(nodes.first)
            else
              nil
            end
          when :all
            if nodes = result['nodes']
              nodes.map do |hash|
                build_record(hash)
              end
            else
              nil
            end
          when :count
            if count = result['count']
              count
            else
              nil
            end
          else
            raise Exception.new("Invalid count should be :all, :first or :count (found #{count.inspect})")
          end
        end

        def search(query, options = {})
          find(:all, {:q => query}, options)
        end

        def all(query, options = {})
          find(:all, query, options)
        end

        def first(query, options = {})
          find(:first, query, options)
        end

        def count(query, options = {})
          find(:count, query, options)
        end

        private
          def build_record(hash)
            Zena::Remote::Node.new(self, hash)
          end
      end # Read

      module ClassMethods
        include Read::Collection
        include Read
      end

      module InstanceMethods
        include Read::Instance
        include Read
      end

    end # Interface
  end # Remote
end # Zena