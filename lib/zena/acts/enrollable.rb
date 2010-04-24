module Zena
  module Acts
    module Enrollable
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
    end # Enrollable
  end # Acts
end # Zena