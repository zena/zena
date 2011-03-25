module Zena
  module Use
    # This module handles the creation and maintenance of a 'fullpath' and cached project/section_id.
    module Ancestry
      module ClassMethods
        def title_join
          %Q{INNER JOIN idx_nodes_ml_strings AS id1 ON id1.node_id = nodes.id AND id1.key = 'title' AND id1.lang = '#{visitor.lang}'}
        end

        # (slow). Find a node by it's path. This is used during node importation when stored as zml files.
        def find_by_path(path, parent_id = current_site.root_id)
          res  = nil
          path = path.split('/') unless path.kind_of?(Array)
          last = path.size - 1
          path.each_with_index do |title, i|
            klass = i == last ? self : Node
            unless p = klass.find(:first,
                :select     => i == last ? 'nodes.*' : 'nodes.id',
                :joins      => title_join,
                :conditions => ["parent_id = ? AND id1.value = ? AND #{secure_scope('nodes')}", parent_id, title]
              )
              # Block as soon as we cannot find an element
              return nil
            end
            parent_id = p['id']
            res = p if i == last
          end
          res
        end

        # (slow). Transform a list of zips into a fullpath.
        def fullpath_map(path, sym = :node)
          path = path.split('/') unless path.kind_of?(Array)
          zips = path.reject{|e| e == '..'}
          case sym
          when :title
            opts = {
              :select => 'zip, id1.value AS title',
              :joins  => title_join,
              :conditions => ["zip IN (?) AND #{secure_scope('nodes')}", zips],
            }
          when :node
            opts = {
              :conditions => ["zip IN (?) AND #{secure_scope('nodes')}", zips],
            }
          else
            # not supported
            raise Exception.new("#{sym} not supported for fullpath_map")
          end


          list = Node.find(:all, opts)

          list = Hash[*(list.map{|e| [e['zip'].to_i, sym == :node ? e : e[sym.to_s]]}).flatten]

          path.map do |zip|
            zip == '..' ? '..' : (list[zip.to_i] || (sym == :node ? nil : '*'))
          end.compact
        end
      end # ClassMethods

      module ModelMethods
        include RubyLess
        safe_context       :ancestors => {:class => ['Node'], :method => 'z_ancestors'}
        safe_method        :fullpath => String, :short_path => String

        def self.included(base)
          base.class_eval do
            # We do not use before_save to make sure this happens after 'zip' is set in 'node_before_create'.
            before_create :rebuild_paths
            before_update :rebuild_paths
            after_save    :rebuild_children_fullpath
            extend ClassMethods
          end
        end

        # Return the list of ancestors as a Zafu compatible context.
        def z_ancestors
          anc = ancestors
          anc.empty? ? nil : anc
        end

        # Return true if the current node is an ancestor for the given child
        def ancestor?(child)
          child.fullpath =~ %r{\A#{fullpath}}
        end

        # Return the list of ancestors (without self): [root, obj, obj]
        # ancestors to which the visitor has no access are removed from the list
        def ancestors(start=[])
          if self[:id] == current_site[:root_id]
            []
          elsif self[:parent_id].nil?
            []
          else
            path = fullpath.split('/')[0..-2]
            [current_site.root_node].compact + (secure(Node) { Node.fullpath_map(path, :node) } || [])
          end
        end

        # url base path. If a node is in 'projects' and projects has custom_base set, the
        # node's basepath becomes 'projects', so the url will be 'projects/node34.html'.
        # The basepath is cached. If rebuild is set to true, the cache is updated.
        def basepath
          self[:basepath]
        end

        # (slow). Return an array with the node title and the last two parents' titles.
        def short_path
          path = (fullpath || '').split('/')
          if path.size > 2
            ['..'] + fullpath_as_title(path[-2..-1])
          else
            fullpath_as_title(path)
          end
        end

        def pseudo_id(root_node, sym)
          case sym
          when :zip
            self.zip
          when :relative_path
            full = self.fullpath
            root = root_node ? root_node.fullpath : ''
            "(#{fullpath_as_title(full.rel_path(root)).map(&:to_filename).join('/')})"
          end
        end

        # (slow). Transform a list of zips into a fullpath.
        def fullpath_as_title(path = fullpath)
          if path == self.fullpath
            # secure returns nil instead of [] so we fix this.
            @fullpath_as_title ||= secure(Node) { Node.fullpath_map(path, :title) } || []
          else
            secure(Node) { Node.fullpath_map(path, :title) } || []
          end
        end

        private

          def rebuild_paths
            # rebuild cached fullpath / basepath
            rebuild_fullpath
            rebuild_basepath
            # we should use a full rebuild when there are corrupt values,
            # if fullpath was blank, we have no way to find all children
            @need_rebuild_children_fullpath = !new_record? && (fullpath_changed? || basepath_changed?) && !fullpath_was.blank?

            true
          end

          def rebuild_fullpath
            return unless new_record? || parent_id_changed? || fullpath.nil?
            if parent = parent(false)
              path = parent.fullpath.split('/') + [zip]
            else
              path = []
            end
            self.fullpath = path.join('/')
          end

          def rebuild_basepath
            return unless new_record? || parent_id_changed? || custom_base_changed? || basepath.nil?
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
              list  = Zena::Db.fetch_attributes(['id', 'fullpath', 'basepath', 'custom_base'], 'nodes', "fullpath LIKE #{Zena::Db.quote("#{fullpath_was}/%")} AND site_id = #{current_site.id} ORDER BY fullpath ASC LIMIT #{batch_size} OFFSET #{i * batch_size}")

              break if list.empty?
              list.each do |rec|
                rec['fullpath'].sub!(fullpath_re, fullpath_new) if fullpath_re
                if rec['custom_base'] == Zena::Db::TRUE_RESULT
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
      end # ModelMethods
    end # Ancestry
  end # Use
end # Zena
