module Zena
  module Use
    # This module handles the creation and maintenance of a 'fullpath' and cached project/section_id.
    module Ancestry
      
      def self.basepath_from_fullpath(fullpath)
        return '' if !fullpath # This happens with pseudo root/home when node is not accessible
        fullpath.split('/')[1..-1].join('/')
      end
      
      # Makes a fullpath from the node's zip and parent zip Array.
      # Returns fullpath as an Array.
      def self.make_fullpath(zip, parent_fullpath)
        if parent_fullpath
          parent_fullpath + [zip]
        else
          [zip]
        end
      end
      
      # Rebuild basepath and return new value
      def self.make_basepath(fullpath, custom_base, parent_basepath)
        if custom_base
          fullpath[1..-1]
        else
          parent_basepath || []
        end
      end
      
      # Forces rebuild of paths. Returns the new paths.
      def self.rebuild_paths(rec, parent_fullpath, parent_basepath)
        id, zip, custom_base = rec['id'], rec['zip'], rec['custom_base']
        custom_base = custom_base == true || custom_base == '1'
        fullpath = make_fullpath(zip, parent_fullpath)
        basepath = make_basepath(fullpath, custom_base, parent_basepath)
        new_paths = {'fullpath' => fullpath.join('/'), 'basepath' => basepath.join('/')}
        if !new_paths.keys.inject(true){|s,e| s && rec[e] == new_paths[e]}
          # Need to save
          log = "[#{zip}] Fix paths: #{rec['fullpath']} => #{new_paths['fullpath']}, #{rec['basepath']} => #{new_paths['basepath']}"
          Rails.logger.warn log
          if RAILS_ENV != 'test'
            # When running rake task
            puts log
          end
          Zena::Db.execute "UPDATE nodes SET #{new_paths.map {|k,v| "#{Zena::Db.connection.quote_column_name(k)}=#{Zena::Db.quote(v)}"}.join(', ')} WHERE id = #{id} AND site_id = #{current_site.id}"
        end
        return fullpath, basepath
      end
      
      # Forces a full recursive basepath and fullpath rebuild. If parent_fullpath and parent_basepath
      # are nil, base is the root node. parent_fullpath and parent_basepath should be provided as Array.
      def self.rebuild_all_paths(rec, parent_fullpath = nil, parent_basepath = nil, visited = {})
        raise Zena::InvalidRecord, "Infinit loop in 'ancestors'. Node zip = #{rec['zip']}." if visited[rec['id']]
        fullpath, basepath = rebuild_paths(rec, parent_fullpath, parent_basepath)
        visited[rec['id']] = true
        
        # Do the same for each child. Depth first. Batch of 100 for children listing.
        i = 0
        batch_size = 100
        while true
          list  = Zena::Db.fetch_attributes(['id', 'zip', 'custom_base', 'fullpath', 'basepath'], 'nodes', "parent_id = #{rec['id']} AND site_id = #{current_site.id} ORDER BY id ASC LIMIT #{batch_size} OFFSET #{i * batch_size}")

          break if list.empty?
          list.each do |child|
            rebuild_all_paths(child, fullpath, basepath, visited)
          end

          if list.size == batch_size
            # 100 more
            i += 1
          else
            break
          end
        end
      end
      
      module ClassMethods
        def title_join
          %Q{INNER JOIN idx_nodes_ml_strings AS id1 ON id1.node_id = nodes.id AND id1.key = 'title' AND id1.lang = '#{visitor.lang}'}
        end

        TITLE_ML_JOIN = %Q{INNER JOIN idx_nodes_ml_strings AS id1 ON id1.node_id = nodes.id AND id1.key = 'title'}

        # (slow). Find a node by it's path. This is used during node importation when stored as zml files or to resolve custom_base url until we have an "alias" table.
        def find_by_path(path, parent_id = current_site.root_id, multilingual = false)
          res  = nil
          path = path.split('/') unless path.kind_of?(Array)
          last = path.size - 1
          path.each_with_index do |title, i|
            klass = i == last ? self : Node
            unless p = klass.find(:first,
                :select     => i == last ? 'nodes.*' : 'nodes.id',
                :joins      => multilingual ? title_join : TITLE_ML_JOIN,
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


          list = Node.send(:with_exclusive_scope) do
            Node.find(:all, opts)
          end

          list = Hash[*(list.map{|e| [e['zip'].to_i, sym == :node ? e : e[sym.to_s]]}).flatten]

          path.map do |zip|
            zip == '..' ? '..' : (list[zip.to_i] || (sym == :node ? nil : '*'))
          end.compact
        end
        
      end # ClassMethods

      module ModelMethods
        include RubyLess
                                         # This is used to defer :class type resolution to compilation time
        safe_method        :ancestors => Proc.new {|h, r, s| {:method => 'z_ancestors', :class => [VirtualClass['Node']], :nil => true}}
        safe_method        :fullpath => String, :short_path => [String]

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
        def is_ancestor?(child)
          # self is it's own ancestor
          child.id       == id                 ||
          # parent
          child.fullpath =~ %r{\A#{fullpath}/} ||
          # root
          id             == current_site.root_id
        end

        # Return the list of ancestors (without self): [root, obj, obj]
        # ancestors to which the visitor has no access are removed from the list
        def ancestors(start=[])
          if id == current_site.root_id
            []
          elsif parent_id.nil?
            []
          else
            path = fullpath.split('/')[1..-2]
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
        def fullpath_as_title(path = nil)
          if !path
            # When using fullpath, we remove first element (root)
            path = fullpath.split('/')[1..-1]
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
              self[:fullpath] = Ancestry.make_fullpath(zip, parent.fullpath.split('/')).join('/')
            else
              self[:fullpath] = Ancestry.make_fullpath(zip, nil).join('/')
            end
          end
          
          def rebuild_basepath
            return unless new_record? || parent_id_changed? || custom_base_changed? || basepath.nil?
            if parent = parent(false)
              parent_basepath = parent.basepath.split('/')
            else
              parent_basepath = nil
            end
            self[:basepath] = Ancestry.make_basepath(self.fullpath.split('/'), custom_base, parent_basepath).join('/')
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
                  rec['basepath'] = Ancestry.basepath_from_fullpath(rec['fullpath'])
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
