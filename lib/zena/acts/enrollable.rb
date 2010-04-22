module Zena
  module Acts
    module Enrollable
      def self.included(base)
        base.class_eval do
          alias_method_chain :attributes=, :enrollable
        end
      end

      def attributes_with_enrollable=(attrs)
        load_roles(all_possible_roles)
        self.attributes_without_enrollable = attrs
      end

      def load_roles(*roles)
        roles.flatten.each do |role|
          has_role role
        end
      end

      def all_possible_roles
        kpaths = []
        kpath.split(//).each_index { |i| kpaths << kpath[0..i] }

        # FIXME: !! manage a memory cache for Roles
        Role.all(:conditions => ['kpath IN (?)', kpaths])
      end
    end # Enrollable
  end # Acts
end # Zena