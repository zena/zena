module Zena
  module Remote
    module Interface

      module Logger
        def logger
          @connection.logger
        end
      end

      # Methods to create new remote nodes.
      module Create
        # Used by @connection.create(...)
        module ConnectionMethods
          def create(attributes)
            node = Zena::Remote::Node.new(self, attributes)
            node.save
            node
          end
        end

        # Used by instance.save
        module InstanceMethods
          def post(*args)
            @connection.post(*args)
          end
        end # InstanceMethods

        # Used by connection['Post'].find(...)
        module ClassMethods
          def create(attributes)
            node = Zena::Remote::Node.new(@connection, attributes.stringify_keys.merge('class' => @name))
            node.save
            node
          end
        end # ClassMethods
      end # Create

      # Methods to retrieve remote nodes.
      module Read
        # Used by @connection.find(...)
        module ConnectionMethods
          def find_url
            "/nodes/search"
          end

          def root
            process_find(:first, 'root', {})
          end
        end

        # Used by instance.find(...)
        module InstanceMethods
          def find_url
            raise Exception.new("Cannot find from a new instance (no id).") unless id
            "/nodes/#{id}/find"
          end

          def get(*args)
            @connection.get(*args)
          end
        end

        # Used by connection['Post'].find(...)
        module ClassMethods
          def find_url
            "/nodes/search"
          end

          def get(*args)
            @connection.get(*args)
          end

          def process_find(count, query, options = {})
            if query.kind_of?(Hash)
              query = query.symbolize_keys
              klass = query.delete(:class) || @name

              query_args = []

              query.each do |key, value|
                query_args << "#{key} = #{Zena::Db.quote(value)}"
              end

              query = "nodes where class like #{klass} and #{query_args.join(' and ')} in site"
            elsif query.kind_of?(String)
              # query must be a filter
              query = "nodes where class like #{@name} and #{query} in site"
            elsif query.kind_of?(Fixnum)
              # query is an id
              query = "nodes where class like #{@name} and id = #{query} in site"
            else
              # no filter
              query = "nodes where class like #{@name} in site"
            end

            super(count, query, options)
          end

          def all(query = nil, options = {})
            process_find(:all, query, options)
          end

          def first(query = nil, options = {})
            process_find(:first, query, options)
          end

          def count(query = nil, options = {})
            process_find(:count, query, options)
          end
        end # ClassMethods

        # Find remote nodes with query builder or indexed search
        def find(count, query = nil, options = {})
          if query.nil?
            query = count
            count = count.kind_of?(Fixnum) ? :first : :all
          end
          process_find(count, query, options)
        end

        def search(query, options = {})
          process_find(:all, {:q => query}, options)
        end

        def all(query, options = {})
          process_find(:all, query, options)
        end

        def first(query, options = {})
          process_find(:first, query, options)
        end

        def count(query, options = {})
          process_find(:count, query, options)
        end


        private
          def process_find(count, query, options)
            if query.kind_of?(String)
              # Consider string as pseudo sql
              result = get(find_url, :query => options.merge(:qb => query, :_find => count))

            elsif query.kind_of?(Fixnum)
              # Find by id (== zip)
              result = get("/nodes/#{query}")

              if node = result['node']
                result = {'nodes' => [node]}
              end

            else
              # Find from indices title = ..., etc
              result = get(find_url, :query => query.merge(options).merge(:_find => count))
            end

            if error = result['error']
              puts error['message']
            end

            case count
            when :first
              if nodes = result['nodes']
                if found_first = nodes.first
                  return build_record(found_first)
                else
                  nil
                end
              else
                nil
              end
            when :all
              if nodes = result['nodes']
                return nodes.map do |hash|
                  build_record(hash)
                end
              else
                []
              end
            when :count
              if count = result['count']
                return count
              else
                nil
              end
            else
              raise Exception.new("Invalid count should be :all, :first or :count (found #{count.inspect})")
            end
          end

          def build_record(hash)
            Zena::Remote::Node.new(self, hash)
          end
      end # Read

      # Methods to update a remote node.
      module Update
        # Used to mass update
        module ConnectionMethods
          def update(query, attributes)
            if nodes = all(query)
              # TODO: ask ?
              logger.info "-\n"
              logger.info "  %-10s: %s" % ['operation', 'mass update']
              logger.info "  %-10s: %s" % ['timestamp', Time.now]
              logger.info "  %-10s: %s" % ['query', query.inspect]
              logger.info "  %-10s: %s" % ['count', nodes.size]
              logger.info "  change:"
              attributes.each do |key, value|
                logger.info "    #{key}: #{value.inspect}"
              end
              nodes.each do |node|
                if node.update_attributes(attributes)
                else
                  puts "Could not update node #{node.id} (#{node.title}): #{node.errors}"
                end
              end
              nodes
            else
              nil
            end
          end
        end

        # Used by instance.find(...)
        module InstanceMethods
          def update_url
            node_url
          end

          def node_url
            "/nodes/#{id}"
          end

          def create_url
            "/nodes"
          end

          def put(*args)
            @connection.put(*args)
          end

          def update_attributes(new_attributes)
            saved_attributes = @attributes.dup
            self.attributes = new_attributes
            if save
              logger.info "-\n"
              logger.info "  %-10s: %s" % ['operation', 'update']
              logger.info "  %-10s: %s" % ['timestamp', Time.now]
              logger.info "  %-10s: %i" % ['node_id', id]
              logger.info "  changes:"
              @attributes.keys.each do |key|
                next if saved_attributes[key] == @attributes[key]
                logger.info "    #{key}:"
                logger.info "      old: #{saved_attributes[key].inspect}"
                logger.info "      new: #{@attributes[key].inspect}"
              end
            else
              false
            end
          end

          def save
            if new_record?
              result = post(create_url, :body => {:node => @attributes})
            else
              result = put(update_url, :body => {:node => @attributes})
            end

            if result.code == 200
              if node = result['node']
                @attributes = node
                true
              elsif errors = result['errors']
                @errors = errors
                false
              else
                puts "Could not save.. error:"
                puts result.inspect
                false
              end
            else
              puts "Could not save.. error:"
              puts result.inspect
              false
            end
          end

          def new_record?
            id.nil?
          end
        end
      end # Update

      # Methods to delete a remote node.
      module Delete
        module ConnectionMethods
          def destroy(query)
            if nodes = all(query)
              # TODO: ask ?
              logger.info "-\n"
              logger.info "  %-10s: %s" % ['operation', 'mass destroy']
              logger.info "  %-10s: %s" % ['timestamp', Time.now]
              logger.info "  %-10s: %s" % ['query', query.inspect]
              logger.info "  %-10s: %s" % ['count', nodes.size]
              nodes.each do |node|
                if node.destroy
                else
                  puts "Could not destroy node #{node.id} (#{node.title}): #{node.errors}"
                end
              end
              nodes
            else
              nil
            end
          end
        end # ConnectionMethods

        module InstanceMethods
          def destroy_url
            node_url
          end

          def destroy
            if id.nil?
              @errors = ["cannot destroy inexistant remote node"]
              return false
            end
            @previous_id = id
            result = @connection.delete(destroy_url)
            if result.code == 200
              logger.info "  %-10s: %s" % ['operation', 'destroy']
              logger.info "  %-10s: %s" % ['timestamp', Time.now]
              logger.info "  %-10s: %s" % ['node_id', id]
              logger.info "  attributes:"
              @attributes.keys.each do |key|
                logger.info "    #{key}: #{@attributes[key].inspect}"
              end
              true
            elsif errors = result['errors']
              @errors = errors
              false
            else
              puts "Could not destroy.. error:"
              puts result.inspect
              false
            end
          end
        end # InstanceMethods
      end # Delete

      # Extends the Connection class
      module ConnectionMethods
        include Create::ConnectionMethods

        include Read
        include Read::ConnectionMethods

        include Update::ConnectionMethods

        include Delete::ConnectionMethods
      end

      # Included in the Remote::Klass class
      module ClassMethods
        include Logger

        include Create::ClassMethods

        include Read
        include Read::ClassMethods
      end

      # Included in the Remote::Node class
      module InstanceMethods
        include Logger

        include Create::InstanceMethods

        include Read
        include Read::InstanceMethods

        include Update::InstanceMethods

        include Delete::InstanceMethods
      end
    end # Interface
  end # Remote
end # Zena