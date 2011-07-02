module Bricks
  module Acls
    module ControllerMethods
      def self.included(base)
        base.alias_method_chain :template_path_from_template_url, :acls
      end
      # If we have an exec skin, we check that t_url points in this skin's
      # directory to avoid letting the user render with any zafu template.
      def template_path_from_template_url_with_acls(template_url=params[:t_url])
        if visitor.exec_acl && skin = visitor.exec_acl.exec_skin
          # Make sure t_url is using templates in the allowed Skin
          skin_name = skin.title.to_filename
          unless template_url[0..skin_name.size] == skin_name + '/'
            # Wrong Skin !
            Node.logger.warn "Bad t_url used in ACL context (#{template_url}). Visitor = #{visitor.id} // #{visitor.login}"
            # We do not raise AccessViolation to not give hints.
            raise ActiveRecord::RecordNotFound
          end
        end
        template_path_from_template_url_without_acls(template_url)
      end
    end

    module UserMethods
      def self.included(base)
        base.class_eval do
          attr_accessor :exec_acl
          alias_method_chain :get_skin, :acls
          alias_method_chain :find_node, :acls
          attr_accessible :use_acls
        end
      end

      def acl_authorized?(action, params, base_node = nil)
        node = nil
        group_ids_bak = group_ids.dup
        acls(action, params[:mode], params[:format]).each do |acl|
          # Load exec_group to execute query
          if acl.exec_group_id
            @group_ids = group_ids_bak + [acl.exec_group_id]
          end
          base_node ||= self.node_without_secure
          if node = acl.authorize?(base_node, params)
            self.exec_acl = acl
            # Keep loaded exec_group
            return node
          end
        end
        raise ActiveRecord::RecordNotFound
      ensure
        unless self.exec_acl
          # Remove loaded exec_group
          @group_ids = group_ids_bak
        end
      end

      # Find all acls for the visitor for a given action. The action should
      # be one of the following: 'create', 'read', 'update', 'delete'. See
      # Acl::ACTIONS.
      def acls(action, mode, format)
        mode = '' if mode.blank?
        # Can the format be blank ?
        format = 'html' if format.blank?
        secure(Acl) { Acl.find(:all,
          :conditions => [
            'group_id IN (?) AND action = ? AND (mode = ? OR mode = ?) AND (format = ? OR format = ?)',
             group_ids, action, '*', mode, '*', format],
          :order => 'priority DESC'
        )} || []
      end

      def get_skin_with_acls(node)
        exec_acl ? exec_acl.exec_skin : get_skin_without_acls(node)
      end

      def find_node_with_acls(path, zip, name, params, method)
        find_node_without_acls(path, zip, name, params, method)
      rescue ActiveRecord::RecordNotFound
        raise unless visitor.use_acls?
        acl_params = params.dup
        if name =~ /^\d+$/
          acl_params[:id] = name
        elsif name
          # Cannot use acl to find by path
          return nil
        else
          acl_params[:id] = zip
        end

        visitor.acl_authorized?(::Acl::ACTION_FROM_METHOD[method], acl_params)
      end
    end # UserMethods
  end # Acls
end # Bricks