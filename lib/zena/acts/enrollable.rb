module Zena
  module Acts
    module Enrollable
      module Named
        def self.included(base)
          class << base
            attr_accessor :to_s
          end
        end
      end

      def self.make_class(klass)
        if klass.kind_of?(VirtualClass)
          res_class = Class.new(klass.real_class) do
            include Named
          end
        elsif klass <= Node
          res_class = Class.new(klass) do
            include Named
          end
        else
          return klass
        end


        res_class.to_s  = klass.name
        res_class.kpath = klass.kpath

        res_class.load_roles!
        res_class
      end

      module Common

        def load_roles!
          return if @roles_loaded
          load_roles(all_possible_roles)
          @roles_loaded = true
        end

        def all_possible_roles
          kpaths = []
          kpath = self.kpath || vclass.kpath
          kpath.split(//).each_index { |i| kpaths << kpath[0..i] }

          # FIXME: !! manage a memory cache for Roles
          Role.all(:conditions => ['kpath IN (?)', kpaths])
        end
      end # Common

      module ModelMethods
        include Common

        def self.included(base)
          base.class_eval do
            alias_method_chain :attributes=, :enrollable
            alias_method_chain :properties=, :enrollable
          end
        end

        def attributes_with_enrollable=(attrs)
          load_roles!
          self.attributes_without_enrollable = attrs
        end

        def properties_with_enrollable=(attrs)
          load_roles!
          self.properties_without_enrollable = attrs
        end

        def load_roles(*roles)
          roles.flatten.each do |role|
            has_role role
          end
        end
      end # ModelMethods

      module ClassMethods
        include Common

        def load_roles(*roles)
          roles.flatten.each do |role|
            has_role role
            role.column_names.each do |col|
              safe_property col
            end
          end
        end
      end # ClassMethods

      module Common
        def get_class(class_name)
          if klass = Node.get_class(class_name)
            Enrollable.make_class(klass)
          else
            nil
          end
        end
      end # Common

      module ZafuMethods
        include Common
      end

      module ControllerMethods
        include Common
      end
    end # Enrollable
  end # Acts
end # Zena