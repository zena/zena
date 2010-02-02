module Dynamo
  # The Dynamo::Attribute module is included in ActiveRecord model for CRUD operations
  # on the dynamics attributes (the dynamos). These ared stored in a table field called 'dynamo'
  # and accessed with #dynamo and dynamo= methods.
  #
  # The dynamo are encoded et decode with a serialization tool than you need to specify seperatly (for instance
  # Dynamo::Serialization::Marshal).
  #
  # The attributes= method filter columns attributes and dynamic attributes in order to store
  # them apart.
  #
  module Attribute

    def self.included(base)
      base.class_eval do
        include InstanceMethods
        include ::Dynamo::Serialization::Marshal
        include ::Dynamo::Declaration
        include ::Dynamo::Dirty

        before_save :encode_dynamo

        alias_method_chain :attributes=,  :dynamo
      end
    end

    module InstanceMethods
      def dynamo
        @dynamo ||= decode_dynamo
      end

      alias_method :dyn, :dynamo

      def dynamo=(value)
        check_kind_of_hash(value)
        @dynamo = value
      end

      alias_method :dyn=, :dynamo=


      def dynamo!
         @dynamo = decode_dynamo
      end

      def dynamo?
        self.respond_to(:dynamo)
      end

      private

        def attributes_with_dynamo=(new_attributes, guard_protected_attributes = true)
          column_attributes, dynamo_attributes = {}, {}
          columns = self.class.column_names

          new_attributes.each do |k,v|
            if columns.include?(k.to_s)
              column_attributes[k] = v
            else
              dynamo_attributes[k] = v
            end
          end
          self.attributes_without_dynamo=(column_attributes) unless column_attributes.empty?

          merge_dynamo(dynamo_attributes)
        end

        def decode_dynamo
          decode(read_attribute('dynamo'))
        end

        def encode_dynamo
          write_attribute('dynamo', encode(@dynamo))
        end

        def check_kind_of_hash(data)
          raise TypeError, 'Argument is not Hash' unless data.kind_of?(Hash)
        end


        def merge_dynamo(new_attributes)
          if @dynamo && !@dynamo.nil? && @dynamo.kind_of?(Hash)
            @dynamo.merge!(new_attributes)
          else
            @dynamo = new_attributes
          end
        end
    end # InstanceMethods
  end # Attribute
end # Dynamo