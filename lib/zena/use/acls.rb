module Zena
  module Use
    module Acls
      module UserMethods
        def self.included(base)
          base.class_eval do
            attr_accessor :exec_acl
            alias_method_chain :get_skin, :acls
            attr_accessible :use_acls
          end
        end

        def acl_authorized?(action, params)
          node = nil
          group_ids_bak = group_ids.dup
          acls(action).each do |acl|
            # Load exec_group to execute query
            self.group_ids = group_ids_bak + [acl.exec_group_id]
            node ||= self.node
            if acl.authorize?(node, params)
              self.exec_acl = acl
              # Keep loaded exec_group
              return true
            end
          end
          false
        ensure
          unless self.exec_acl
            self.group_ids = group_ids_bak
          end
        end

        # Find all acls for the visitor for a given action. The action should
        # be one of the following: 'create', 'read', 'update', 'delete'. See
        # Acl::ACTIONS.
        def acls(action)
          secure(Acls) { Acls.find(:all,
            :conditions => ['group_id IN (?) and action = ?', group_ids, action],
            :order => 'priority DESC'
          )}
        end

        def get_skin_with_acls(node)
          exec_acl ? exec_acl.exec_skin : get_skin_without_acls(node)
        end
      end # UserMethods
    end # Acls
  end # Use
end # Zena