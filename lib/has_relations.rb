module Zena
  module Relations
    def self.plural_method?(method)
      m = method.split('_').first
      m.pluralize == m || method.ends_with?('_for')
    end
  
    module HasRelations
      # this is called when the module is included into the 'base' module
      def self.included(base)
        # add all methods from the module "AddActsAsMethod" to the 'base' module
        base.extend Zena::Relations::ClassMethods
      end
    end
    
    module ClassMethods
      def has_relations(opts={})
        opts[:class] ||= self
        validate      :valid_links
        after_save    :update_links
        after_destroy :destroy_links
        
        class_eval <<-END
        include Zena::Relations::InstanceMethods
          def relation_base_class
            #{opts[:class]}
          end
        END
      end
      
      def split_kpath
        @split_kpath ||= begin
          klasses   = []
          kpath.split(//).each_index { |i| klasses << kpath[0..i] } 
          klasses
        end
      end
      
      def has_relation?(rel, opts={})
        opts[:role] = rel
        find_relation(opts)
      end

      def find_relation(opts)
        role_name = (opts[:role] || '').singularize
        if opts[:id]
          if opts[:source]
            conditions = ["site_id = ? AND id = ? AND source_kpath IN (?)", current_site[:id], opts[:id], split_kpath]
          else
            conditions = ["site_id = ? AND id = ? AND target_kpath IN (?)", current_site[:id], opts[:id], split_kpath]
          end
        else
          if opts[:from] || opts[:ignore_source]
            conditions = ["site_id = ? AND (target_role = ? OR source_role = ?)", current_site[:id], role_name, role_name]
          else
            conditions = ["site_id = ? AND ((target_role = ? AND source_kpath IN (?)) OR (source_role = ? AND target_kpath IN (?)))", current_site[:id], role_name, split_kpath, role_name, split_kpath]
          end
        end
        relation = Relation.find(:first, :conditions => conditions)
        return nil unless relation
        if opts[:start]
          if relation.target_role == role_name
            relation.source = opts[:start]
          else
            relation.target = opts[:start]
          end
        elsif opts[:source]
          relation.source = opts[:source]
        else
          relation.target = opts[:target]
        end
        relation
      end
      
      def find_all_relations(start=nil)
        rel_as_source = Relation.find(:all, :conditions => ["site_id = ? AND source_kpath IN (?)", current_site[:id], split_kpath])
        rel_as_target = Relation.find(:all, :conditions => ["site_id = ? AND target_kpath IN (?)", current_site[:id], split_kpath])
        rel_as_source.each {|rel| rel.source = start } if start
        rel_as_target.each {|rel| rel.target = start } if start
        (rel_as_source + rel_as_target).sort {|a,b| a.other_role <=> b.other_role}
      end
      
      # Return an sql query string that will be used by 'do_relation_query':
      # build_find(:all, :relations=>['children']) => "SELECT * FROM nodes WHERE nodes.parent_id = #{@node[:id]} AND ..."
      # @node.do_find(:all, "SELECT * FROM nodes WHERE nodes.parent_id = #{@node[:id]} AND ...")
      # Options are 
      # :node=>'@node': contextual variable name
      # :relations=>['notes from site', 'added_notes']: what to find
      # :limit, :conditions, :order
      def build_find(count, opts)
        plural = (count == :all)
        if !plural
          opts[:limit] = 1
        end

        relations = opts.delete(:relations)
        base_conditions, joins = build_condition(opts[:node], *relations)
        
        
        if opts[:conditions]
          opts[:conditions] = "#{base_conditions} AND #{opts[:conditions]} AND #{Node.secure_scope_string}"
        else
          opts[:conditions] = "#{base_conditions} AND #{secure_scope_string}"
        end

        opts[:order] ||= 'position ASC, name ASC'

        if joins =~ /links\./
          opts = clean_options(opts).merge( 
                          :select     => "nodes.*, links.id AS link_id", 
                          :joins      => joins,
                          :group      => 'nodes.id'
                          )
        else
          opts = clean_options(opts).merge(
                          :select     => "nodes.*",
                          :group      => 'nodes.id',
                          :joins      => joins
                          )
        end
        
        construct_finder_sql(opts)
      end
      
      # Build query for compiled sql (used by has_relations and zafu)
      def secure_scope_string
        # ANY CHANGE HERE SHOULD BE REFLECTED IN secure
        "(#{Node.table_name}.user_id = '\#{visitor[:id]}' OR "+
        "(rgroup_id IN (\#{visitor.group_ids.join(',')}) AND #{Node.table_name}.publish_from <= now() ) OR " +
        "(pgroup_id IN (\#{visitor.group_ids.join(',')}) AND max_status > #{Zena::Status[:red]})) AND #{Node.table_name}.site_id = \#{visitor.site[:id]}"
      end
      
      
      # Build a finder for a list of relations. Valid relation syntax is 'RELATION [from|to] [site|section|project]'. For
      # example: 'pages from project', 'images from site', 'tags', 'icon_for from project', 'houses where d_town = Lausanne'
      def build_condition(obj, *finders)
        parts = []
        link_counter = 0
        dyn_counter  = 0
        has_version_join = false
        version_join = "INNER JOIN versions AS vs ON vs.node_id = nodes.id AND ((vs.status >= #{Zena::Status[:red]} AND vs.user_id = \#{visitor[:id]} AND vs.lang = '\#{visitor.lang}') OR vs.status > #{Zena::Status[:red]})"
        joins = []
        
        # Finders will be joined together with an 'OR'
        finders.each do |rule|
          opts = {}
          from = nil
          
          # extract 'where'
          rules = rule.split(/\s+where\s+/)
          where = rules[1]
          
          # extract 'role' and 'from'
          rules = rules[0].split(/\s+/)
          
          if rules.size > 1 && rules.size % 2 == 1
            # 'pages from project' => finder = 'page' and opts = {:from => 'project'}
            finder = rules.shift.singularize
            opts = Hash[*rules]
            opts.keys.each {|key| opts[key.to_sym] = opts[key]; opts.delete(key) }
          else
            # no arguments or bad argument count (ignore arguments)
            finder = rules[0].singularize
          end
          
          if where
            dyn_counter_this_finder = 0
            # someday, someone will ask for an 'or'. When this happens, we need to use () around all the clauses ((...) OR (...)).
            where_clause = where.split(/\s+and\s+/).map do |clause|
              # [field] [=|>]
              if clause =~ /([\w:]+)\s*(<|<=|=|>=|>|<>)\s*"?([^"]*)"?/
                field = $1
                op    = $2
                value = $3
                if value =~ /\[(visitor|param):(\w+)\]/
                  case $1
                  when 'visitor'
                    value = "\#{Node.connection.quote(#{Node.zafu_attribute('visitor.contact', $2)})}"
                  when 'param'
                    value = "\#{Node.connection.quote(params[:#{$2}])}"
                  end
                else
                  value = Node.connection.quote(value)
                end
                case field[0..1]
                when 'd_'
                  # DYNAMIC ATTRIBUTE
                  field = field[2..-1]
                  dyn_counter_this_finder += 1
                  if dyn_counter_this_finder > dyn_counter
                    dyn_counter += 1
                    unless has_version_join
                      joins << version_join
                      has_version_join = true
                    end
                    joins << "INNER JOIN dyn_attributes AS da#{dyn_counter} ON da#{dyn_counter}.owner_id = vs.id AND da#{dyn_counter}.owner_table = 'versions'"
                  end
                  "da#{dyn_counter_this_finder}.key = '#{field}' AND da#{dyn_counter_this_finder}.value #{op} #{value}"
                when 'c_'
                  # CONTENT TABLE
                  field = field[2..-1]
                  # FIXME: implement #41
                  nil
                when 'v_'
                  # VERSION
                  field = field[2..-1]
                  field, function = parse_sql_function_in_field(field)
                  if Version.zafu_readable?(field) && Version.column_names.include?(field)
                    unless has_version_join
                      joins << version_join
                      has_version_join = true
                    end
                    if function
                      "#{function}(vs.#{field}) #{op} #{value}"
                    else
                      "vs.#{field} #{op} #{value}"
                    end
                  else
                    nil
                  end
                else
                  # NODE
                  field, function = parse_sql_function_in_field(field)
                  if Node.zafu_readable?(field) && Node.column_names.include?(field)
                    if function
                      "#{function}(#{field}) #{op} #{value}"
                    else
                      "#{field} #{op} #{value}"
                    end
                  else
                    nil
                  end
                end
              else
                # invalid clause format
                # FIXME: display the error in the rendered zafu #42
              end
            end.compact.join(' AND ')
            where_clause = " AND #{where_clause}"
          else
            where_clause = ''
          end
            
          
          from_clause = case opts[:from]
          when 'site'
            ""
          when 'section'
            " AND nodes.section_id = \#{#{obj}.get_section_id}"
          when 'project'
            " AND nodes.project_id = \#{#{obj}.get_project_id}"
          else
            " AND nodes.parent_id = \#{#{obj}[:id]}"
          end
          
          to_clause = case opts[:to]
          when 'site'
            ""
          when 'section'
            " AND source_nodes.section_id = \#{#{obj}.get_section_id}"
          when 'project'
            " AND source_nodes.project_id = \#{#{obj}.get_project_id}"
          else
            nil
          end
          
          if finder =~ /\A\d+\Z/
            parts << "(nodes.zip = #{finder})"
          elsif base_condition = base_condition(obj, finder)
            # parent, project, section, children, pages, ...
            parts << "#{base_condition}#{from_clause}#{where_clause}"
          elsif klass = Node.get_class(finder)
            # images, documents, ... or virtual class: posts, letters, ...
            parts << "nodes.kpath LIKE '#{klass.kpath}%'#{from_clause}#{where_clause}"
          elsif rel   = Relation.find_by_role(finder)
            # icon, icon_for, added_notes, ...
            if to_clause
              # FIXME: finish this part (add JOIN nodes AS source_nodes ON ... from clause ... )
              # parts << "(links.relation_id = #{rel[:id]} AND links.#{rel.other_side} = nodes.id AND links.#{rel.link_side} = source_nodes.id#{source_clause})"
            else
              link_counter += 1
              parts << "lk#{link_counter}.relation_id = #{rel[:id]} AND lk#{link_counter}.#{rel.other_side} = \#{#{obj}[:id]}#{where_clause}"
              joins << "LEFT JOIN links AS lk#{link_counter} ON lk#{link_counter}.#{rel.link_side} = nodes.id"
            end
          else
            # bad finder. Ignore.
          end
        end
        if parts == []
          ['nodes.id IS NULL', joins.join(' ')]
        elsif parts.size == 1
          [parts.first, joins.join(' ')]
        else
          ['((' + parts.join(') OR (') + '))', joins.join(' ')]
        end
      end
      
      # When a field is defined as log_at:year, return [log_at, year].
      def parse_sql_function_in_field(field)
        if field =~ /\A(\w+):(\w+)\Z/
          if ['year'].include?($2)
            [$1,$2]
          else
            [$1]
          end
        else
          [field]
        end
      end
      
      # 'root', 'project', 'section', 'parent', 'self', 'nodes', 'projects', 'sections', 'children', 'pages', 'documents', 'documents_only', 'images', 'notes', 'author', 'traductions', 'versions'
      def base_condition(obj, method)
        case method
        when 'root'
          "nodes.id = #{current_site.root_id}"
        when 'project'
          "nodes.id = #{self[:project_id]}"
        when 'section'
          "nodes.id = #{self[:section_id]}"
        when 'parent'
          self[:parent_id] ? "id = #{self[:parent_id]}" : "id IS NULL"
        when 'self'  
          "nodes.id = #{self[:id]}"
        when 'author'
          "nodes.id = #{user.contact_id}"
        when 'visitor'
          "nodes.id = #{visitor.contact_id}"
        when 'traductions', 'versions'
          'id IS NULL' # FIXME

          # yes, I know, this is not very elegant, we should find some common way to access 'documents without images'
          # and 'pages without documents'. But we DO need the 'pages' shortcut and not some <r:pages without='documents'/>
        when 'documents_only'
          "nodes.kpath LIKE '#{Document.kpath}%' AND kpath NOT LIKE '#{Image.kpath}%'"
        when 'page'
          "nodes.kpath LIKE '#{Page.kpath}%' AND kpath NOT LIKE '#{Document.kpath}%'"
        when 'all_page'
          "nodes.kpath LIKE '#{Page.kpath}%'"
        when 'children', 'node'
          "1" # no filter
        else
          nil
        end
      end
      

    end
    

    module InstanceMethods

      # Build a finder for a list of relations. Valid relation syntax is 'RELATION [from|to] [site|section|project]'. For
      # example: 'pages from project', 'images from site', 'tags', 'icon_for from project'
      def build_condition(*finders)
        parts = []
        
        # Finders will be joined together with an 'OR'
        finders.each do |rule|
          opts = {}
          from = nil
          rules = rule.split(/\s+/)
          
          if rules.size > 1 && rules.size % 2 == 1
            # 'pages from project' => finder = 'page' and opts = {:from => 'project'}
            finder = rules.shift
            opts = Hash[*rules]
            opts.keys.each {|key| opts[key.to_sym] = opts[key]; opts.delete(key) }
          else
            # no arguments or bad argument count (ignore arguments)
            finder = rules[0]
          end
          
          from_clause = case opts[:from]
          when 'site'
            ""
          when 'section'
            " AND nodes.section_id = #{get_section_id}"
          when 'project'
            " AND nodes.project_id = #{get_project_id}"
          else
            " AND nodes.parent_id = #{self[:id].to_i}"
          end
          
          to_clause = case opts[:to]
          when 'site'
            ""
          when 'section'
            " AND source_nodes.section_id = #{get_section_id}"
          when 'project'
            " AND source_nodes.project_id = #{get_project_id}"
          else
            nil
          end
          
          if finder =~ /\A\d+\Z/
            parts << "(nodes.zip = #{finder})"
          elsif base_condition = self.base_condition(finder)
            # parent, project, section, children, pages, ...
            parts << "(#{base_condition}#{from_clause})"
          elsif klass = Node.get_class(finder)
            # images, documents, ... or virtual class: posts, letters, ...
            parts << "(nodes.kpath LIKE '#{klass.kpath}%'#{from_clause})"
          elsif rel   = Relation.find_by_role(finder)
            # icon, icon_for, added_notes, ...
            if to_clause
              # FIXME: finish this part (add JOIN nodes AS source_nodes ON ... from clause ... )
              # parts << "(links.relation_id = #{rel[:id]} AND links.#{rel.other_side} = nodes.id AND links.#{rel.link_side} = source_nodes.id#{source_clause})"
            else
              parts << "(links.relation_id = #{rel[:id]} AND links.#{rel.link_side} = nodes.id AND links.#{rel.other_side} = #{self[:id]})"
            end
          else
            # bad finder. Ignore.
          end
        end
        if parts == []
          'nodes.id IS NULL'
        else
          parts.join(' OR ')
        end
      end
      
      
      def do_find(count, query)
        return nil if new_record?
        res = Node.find_by_sql(query)
        if count == :all
          res == [] ? nil : res
        elsif
          res.first
        end
      end
      
      # <notes or='added_notes' limit='3'>...</notes>
      # node.find(:all, :relations=>['notes', 'added_notes'], :order=>'', :limit=>3, :order=>'', :conditions=>'')
      
      # <houses from='site' d_type='villa'>...</houses>
      # node.find(:all, :relations=>{:role=>'house', :from=>'site', :d_type=>'villa'}'houses from site where d_type = "villa"'],...)
      
      def find(count, options)
        return nil if new_record?
        if options.kind_of?(String)
          opts = {:relations=>options}
        else
          opts = options.dup
        end
        
        plural = (count == :all)
        if !plural
          opts[:limit] = 1
        end
        
        relations = opts.delete(:relations)
        relations = [relations] unless relations.kind_of?(Array)
        base_conditions = build_condition(*relations)
        if cond = opts[:conditions]
          if cond.kind_of?(Array)
            opts[:conditions] = ["(#{cond[0]}) AND (#{base_conditions})"] + cond[1..-1]
          else
            opts[:conditions] = "(#{cond}) AND (#{base_conditions})"
          end
        else
          opts[:conditions]   = base_conditions
        end
        
        opts[:order] ||= 'position ASC, name ASC'
        
        if base_conditions =~ /links\./
          opts = Node.clean_options(opts).merge( 
                          :select     => "nodes.*, links.id AS link_id", 
                          :joins      => "INNER JOIN links",
                          :group      => 'nodes.id'
                          )
        else
          opts = Node.clean_options(opts).merge(
                          :group      => 'nodes.id'
                          )
        end
        
        secure(Node) { Node.find(count, opts) }
        
      rescue ActiveRecord::RecordNotFound
        nil
      end
      
      def set_relation(role, value)
        @relations_to_update ||= []
        @relations_to_update << [:set, [role, value]]
      end
      
      def remove_link(link_id)
        @relations_to_update ||= []
        @relations_to_update << [:remove, link_id]
      end
      
      def add_link(role, value)
        @relations_to_update ||= []
        @relations_to_update << [:add, [role, value]]
      end
      
      def find_all_relations
        @all_relations ||= self.vclass.find_all_relations(self)
      end

      def relations_for_form
        find_all_relations.map {|r| [r.other_role.singularize, r.other_role]}
      end
      
      # List the links, grouped by role
      def relation_links
        res = []
        find_all_relations.each do |relation|
          #if relation.record_count > 5
          #  # FIXME: show message ?
          #end
          links = relation.records(:limit => 5, :select => "nodes.*, links.id AS link_id", :order => "link_id DESC") rescue nil
          res << [relation, links] if links
        end
        res
      end
      
      
      # REWRITE TO HERE
      
      def relation_proxy(opts={})
        opts = {:role => opts} unless opts.kind_of?(Hash)
        rel_opts = {}
        if role = opts[:role]
          rel_opts[:role] = role
          rel_opts[:ignore_source] = true if opts[:ignore_source] || opts[:from] || opts[:or]
          rel_opts[:start] = self
        elsif link = opts[:link]
          return nil unless link
          rel_opts[:id] = link.relation_id
          if link.source_id == self[:id]
            rel_opts[:source] = self
          else
            rel_opts[:target] = self
          end
        end
        self.vclass.find_relation(rel_opts)
      end
      
      private
      
        def valid_links
          return true unless @relations_to_update
          @valid_relations_to_update = []
          @relations_to_update.map do |action, params|
            case action
            when :set
              role, value = params
              if relation = relation_proxy(:role => role)
                relation.new_value = value
                if relation.links_valid?
                  @valid_relations_to_update << relation
                else
                  errors.add(role, relation.link_errors.join(', '))
                end
              else
                errors.add(role, 'undefined relation')
              end
            when :add
              role, value = params
              if relation = relation_proxy(:role => role)
                relation << value
                if relation.links_valid?
                  @valid_relations_to_update << relation
                else
                  errors.add(role, relation.link_errors.join(', '))
                end
              else
                errors.add(role, 'undefined relation')
              end
            when :remove
              link_id = params
              link = Link.find(:first, :conditions => ['(source_id = ? OR target_id = ?) AND id = ?', self[:id], self[:id], link_id])
              if relation = relation_proxy(:link => link)
                if link['source_id'] == self[:id]
                  relation.delete(link['target_id'])
                else
                  relation.delete(link['source_id'])
                end
                if relation.links_valid?
                  @valid_relations_to_update << relation
                else
                  errors.add(role, relation.link_errors.join(', '))
                end
              else
                errors.add('base', 'unknown link')
              end
            end
          end
        
        end
      
        def update_links
          return if @valid_relations_to_update.blank?
          @valid_relations_to_update.each do |relation|
            relation.update_links!
          end
          remove_instance_variable(:@valid_relations_to_update)
          remove_instance_variable(:@relations_to_update)
        end
        
        def destroy_links
          Link.find(:all, :conditions => ["source_id = ? OR target_id = ?", self[:id], self[:id]]).each do |l|
            l.destroy
          end
        end
        
        # shortcut accessors like tags_id = ...
        def method_missing(meth, *args)
          super
        rescue NoMethodError => err
          if meth.to_s =~ /^([\w_]+)_(ids?|zips?)(=?)$/
            role = $1
            type = $2
            plural = ($2[-1..-1] == 's')
            mode = $3
            if relation = relation_proxy(:role => role)
              if mode == '='
                super if type[0..-2] == 'zip'
                # add_link
                set_relation(role,args[0])
              else
                # get ids / zips
                relation.send("other_#{type}")
              end
            else
              raise err # unknown relation
            end
          elsif meth.to_s[-1..-1] != '=' && relation = relation_proxy(:role => meth.to_s)
            relation.unique? ? relation.record : relation.records
          else
            raise err # no _zip / _id
          end
        end
    end
  end
end

ActiveRecord::Base.send :include, Zena::Relations::HasRelations