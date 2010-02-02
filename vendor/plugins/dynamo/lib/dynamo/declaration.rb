module Dynamo

  # Dynamo::Declaration module is used to declare Dynamos in a Class. It manage also
  # inheritency of Dynamos.
  module Declaration

    def self.included(base)
      base.class_eval do
        extend  ClassMethods
        include InstanceMethods

        validate :dynamo_property_validation, :if=>:dynamo
      end
    end

    module ClassMethods
      def dynamo(name, type, options={})
        prop = Dynamo::Property.new(name, type, options)
        if dynamos[name].blank?
          dynamos[name] = prop
        end
      end

      def dynamos
        @dynamos ||= if parent = parent_model
          parent.dynamos.dup
        else
          HashWithIndifferentAccess.new
        end
      end

      def parent_model
        (ancestors - [self, Dynamo::Attribute]).find do |parent|
          parent.include?(Dynamo::Attribute)
        end
      end
    end # ClassMethods

    module InstanceMethods
      def dynamos_declared
        @dynamos_declared ||= self.class.dynamos
      end

      protected

        def dynamo_property_validation
          dynamo.each do |dyn, value|
            declaration_validation(dyn)
            data_type_validation(dyn, value)
          end
        end

        def declaration_validation(dyn)
          unless dynamos_declared.has_key?(dyn)
            errors.add("#{dyn}", "dynamo is not declared")
          end
        end

        def data_type_validation(dyn, value)
          if declared_dyn = dynamos_declared[dyn]
            if !value.kind_of?( type = declared_dyn.data_type)
              errors.add("#{dyn}", "dynamo has wrong data type. Received #{value.class}, expected #{type}")
            end
          end
        end
    end # InsanceMethods
  end # Declaration
end # Dynamo