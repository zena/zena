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
            before_validation  :prepare_roles
            after_save  :update_roles
            after_destroy :destroy_nodes_roles
            has_and_belongs_to_many :roles

            property do |p|
              p.serialize :cached_role_ids, Array
            end
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

        def has_role?(role_id)
          (cached_role_ids || []).include?(role_id)
        end

        private
          # Prepare roles to add/remove to object.
          def prepare_roles
            return unless prop.changed?

            keys = []
            properties.each do |k, v|
              keys << k unless v.blank?
            end

            role_ids = []
            schema.roles.flatten.uniq.each do |role|
              next unless role.kind_of?(Role)
              role_ids << role.id if role.column_names & keys != []
            end

            prop['cached_role_ids'] = role_ids
          end

          def update_roles
            return if version.status < Zena::Status[:pub]

            # High status, rebuild role index

            if cached_role_ids.blank?
              Zena::Db.execute("DELETE FROM nodes_roles WHERE node_id = #{Zena::Db.quote(self.id)}")
            else
              current_ids = Zena::Db.fetch_ids("SELECT role_id FROM nodes_roles WHERE node_id = #{Zena::Db.quote(self.id)}", 'role_id')
              add_roles = cached_role_ids - current_ids
              del_roles = current_ids - cached_role_ids

              if !add_roles.blank?
                Zena::Db.insert_many('nodes_roles', %W{node_id role_id}, add_roles.map {|role_id| [self.id, role_id]})
              end

              if !del_roles.blank?
                Zena::Db.execute("DELETE FROM nodes_roles WHERE node_id = #{Zena::Db.quote(self.id)} AND role_id IN (#{del_roles.map{|r| Zena::Db.quote(r)}.join(',')})")
              end
            end
          end

          def destroy_nodes_roles
            Zena::Db.execute("DELETE FROM nodes_roles WHERE node_id = #{Zena::Db.quote(self.id)}")
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