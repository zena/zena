module Bricks
  module Acls
    module ControllerMethods
      def self.included(base)
        base.alias_method_chain :template_path_from_template_url, :acls
      end
      # If we have an exec skin, we check that t_url points in this skin's
      # directory to avoid letting the user render with any zafu template.
      def template_path_from_template_url_with_acls(suffix='', template_url=params[:t_url], build=true)
        if visitor.exec_acl && skin = visitor.exec_acl.exec_skin
          # Make sure t_url is using templates in the allowed Skin
          skin_name = skin.skin_name
          unless template_url[0..skin_name.size] == skin_name + '/'
            # Wrong Skin !
            Node.logger.warn "Bad t_url used in ACL context (#{template_url}). Visitor = #{visitor.id} // #{visitor.login}"
            # We do not raise AccessViolation to not give hints.
            raise ActiveRecord::RecordNotFound
          end
        end
        template_path_from_template_url_without_acls(suffix, template_url, build)
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

      def acl_authorized?(action, params, request)
        node = nil
        group_ids_bak = group_ids.dup
        if action == 'create'
          klass = (params['node'] || {})['klass']
        end
        
        acls(action, params[:mode], params[:format], klass).each do |acl|
          # Load exec_group to execute query
          if acl.exec_group_id
            @group_ids = group_ids_bak + [acl.exec_group_id]
          end
          base_node = self.node_without_secure
          if node = acl.authorize?(base_node, params, request)
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
      # Acl::ACTIONS. If the action is 'create', we should also pass the class
      # of the object to create.
      def acls(action, mode, format, klass = nil)
        mode = '' if mode.blank?
        # Can the format be blank ?
        format = 'html' if format.blank?
        if action == 'create'
          return [] unless klass = VirtualClass[klass || 'Node']
          # Can the format be blank ?
          format = 'html' if format.blank?
          secure(Acl) { Acl.find(:all,
            :conditions => [
              'group_id IN (?) AND action = ? AND (mode = ? OR mode = ?) AND (format = ? OR format = ?) AND create_kpath IN (?)',
               group_ids, action, '*', mode, '*', format, klass.split_kpath],
            :order => 'priority DESC'
          )}
        else
          secure(Acl) { Acl.find(:all,
            :conditions => [
              'group_id IN (?) AND action = ? AND (mode = ? OR mode = ?) AND (format = ? OR format = ?)',
               group_ids, action, '*', mode, '*', format],
            :order => 'priority DESC'
          )}
        end || []
      end

      def get_skin_with_acls(node)
        exec_acl ? exec_acl.exec_skin : get_skin_without_acls(node)
      end

      def find_node_with_acls(path, zip, name, request, need_write = false)
        n = find_node_without_acls(path, zip, name, request, need_write) rescue nil
        if !n || (!n.can_write? && need_write)
          n = find_node_force_acls(path, zip, name, request) || n
        end
        n
      end
      
      def find_node_force_acls(path, zip, name, request)
        raise ActiveRecord::RecordNotFound unless visitor.use_acls?
        acl_params = request.params.dup
        if name =~ /^\d+$/
          acl_params[:id] = name
        elsif name
          # Cannot use acl to find by path
          return nil
        else
          acl_params[:id] = zip
        end
        if request.path =~ %r{^/nodes/\d+/zafu$}
          # This is to allow preview by using POST requests (long text in js).
          action = 'read'
        else
          action = ::Acl::ACTION_FROM_METHOD[request.method]
        end
        visitor.acl_authorized?(action, acl_params, request)
      end
    end # UserMethods
  end # Acls
end # Bricks