module Zena
  module Use
    # This module handles the creation and maintenance of a 'node_name' and a path built from
    # these node_names (fullpath).
    #
    # This module has to be included after Workflow so that v_status is properly
    # set before 'sync_node_name' is called.
    module NodeName
      def self.included(base)
        base.before_validation :sync_node_name
        base.after_save        :rebuild_children_fullpath
      end

      private
        # Store part of the title into the node (used when accessing the database with a
        # console).
        def sync_node_name
          # Sync if we are publishing
          if ((full_drive? && v_status == Zena::Status[:pub]) ||
              (can_drive?  && vhash['r'][ref_lang].nil?))
            self.node_name = title
            if !new_record? && kind_of?(Page) && node_name_changed?
              # we only rebuild Page node_names on update
              get_unique_node_name_in_scope('NP%')
            end
          end

          unless node_name.blank?
            # rebuild cached fullpath / basepath
            rebuild_fullpath
            rebuild_basepath
            # we should use a full rebuild when there are corrupt values,
            # if fullpath was blank, we have no way to find all children
            @need_rebuild_children_fullpath = !new_record? && (fullpath_changed? || basepath_changed?) && !fullpath_was.blank?
          end

          true
        end

        def rebuild_fullpath
          return unless new_record? || node_name_changed? || parent_id_changed? || fullpath.nil?
          if parent = parent(false)
            path = parent.fullpath.split('/') + [node_name]
          else
            path = []
          end
          self[:fullpath] = path.join('/')
        end

        def rebuild_basepath
          return unless new_record? || node_name_changed? || parent_id_changed? || custom_base_changed? || basepath.nil?
          if custom_base
            self[:basepath] = self.fullpath
          elsif parent = parent(false)
            self[:basepath] = parent.basepath || ""
          else
            self[:basepath] = ""
          end
        end

        def rebuild_children_fullpath
          return true unless @need_rebuild_children_fullpath

          # Update descendants
          fullpath_new = self.fullpath
          fullpath_new = "#{fullpath_new}/" if fullpath_was == ''
          fullpath_re  = fullpath_changed? ? %r{\A#{self.fullpath_was}} : nil

          bases = [self.basepath]

          i = 0
          batch_size = 100
          while true
            list  = Zena::Db.fetch_attributes(['id', 'fullpath', 'basepath', 'custom_base'], 'nodes', "fullpath LIKE #{Zena::Db.quote("#{fullpath_was}%")} AND site_id = #{current_site.id} ORDER BY fullpath ASC LIMIT #{batch_size} OFFSET #{i * batch_size}")
            break if list.empty?
            list.each do |rec|
              rec['fullpath'].sub!(fullpath_re, fullpath_new) if fullpath_re
              if rec['custom_base'].to_i == 1
                rec['basepath'] = rec['fullpath']
                bases << rec['basepath']
              else
                while rec['fullpath'].size <= bases.last.size
                  bases.pop
                end
                rec['basepath'] = bases.last
              end
              id = rec.delete('id')
              Zena::Db.execute "UPDATE nodes SET #{rec.map {|k,v| "#{Zena::Db.connection.quote_column_name(k)}=#{Zena::Db.quote(v)}"}.join(', ')} WHERE id = #{id}"
            end
            # 50 more
            i += 1
          end
          true
        end
    end # NodeName
  end # Use
end # Zena
