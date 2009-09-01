require 'active_record/fixtures'

module Zena
  # mass yaml loader for ActiveRecord (a single file can contain different classes)
  module Loader
    class YamlLoader < ActiveRecord::Base
      class << self
        def set_table(tbl)
          set_table_name tbl
          reset_column_information
        end
        
        def create_or_update(opts)
          h = {}
          opts.each_pair do |k,v|
            if :type == k
              h['_type_'] = v
            else
              h[k.to_s] = v
            end
          end
          
          if h['id'] && obj = find_by_id(h['id'])
            res = []
            h.each do |k,v|
              res << "`#{k}` = #{v ? v.inspect : 'NULL'}"
            end
            connection.execute "UPDATE #{table_name}  SET #{res.join(', ')} WHERE id = #{h['id']}"
          else
            keys   = []
            values = []
            h.each do |k,v|
              keys   << "`#{k}`"
              values << (v ? v.inspect : 'NULL')
            end
            connection.execute "INSERT INTO #{table_name} (#{keys.join(', ')}) VALUES (#{values.join(', ')})"
          end
        end
      end
      
      def site_id=(i)
        self[:site_id] = i
      end
      
      def _type_=(t)
        self.type = t
      end
    end

    def self.load_file(filepath)
      raise Exception.new("Invalid filepath for loader (#{filepath})") unless ((filepath =~ /.+\.yml$/) && File.exist?(filepath))
      base_objects = {}
      YAML::load_documents( File.open( filepath ) ) do |doc|
        doc.each do |elem|
          list = elem[1].map do |l|
            hash = {}
            l.each_pair do |k, v|
              hash[k.to_sym] = v
            end
            hash
          end
          tbl = elem[0].to_sym
          if base_objects[tbl]
            base_objects[tbl] += list
          else
            base_objects[tbl] = list
          end
        end
      end

      base_objects.each_pair do |tbl, list|
        YamlLoader.set_table(tbl.to_s)
        list.each do |record|
          YamlLoader.create_or_update(record)
        end
      end
    end
  end
  
  class FoxyParser
    attr_reader :column_names, :table, :elements, :site, :name, :defaults
    @@parser_for_table = {}
    
    class << self
      def id(site, key)
        return nil if key.blank?
        if key == 0 # special rgroup, wgroup, pgroup values...
          key
        else
          Fixtures.identify("#{site}_#{key}")
        end
      end

      def multi_site_id(key)
        return nil if key.blank?
        Fixtures.identify(key)
      end

      def multi_site_tables
        ['users', 'sites']
      end
      
      # included at start of fixture file
      def prelude
        ""
      end
    
      alias o_new new
    
      def new(table_name, opts={})
        class_name = "Foxy#{table_name.to_s.camelcase}Parser"
        begin
          klass = eval(class_name) # Module.const_get not working for some strange reason...
          raise ArgumentError unless klass.ancestors.include?(FoxyParser)
        rescue ArgumentError
          klass = self
        end
        klass.o_new(table_name.to_s, opts)
      end
      
      def parses(table_name)
        @@parser_for_table[table_name.to_s] = self
      end
    end
    
    def initialize(table_name, opts={})
      @table = table_name
      @column_names = Node.connection.columns(table).map {|c| c.name }
      @elements = {}
      @options  = opts
    end
    
    def run
      
      Dir.foreach("#{RAILS_ROOT}/test/sites") do |site|
        next if site =~ /^\./
        @site = site
        parse_fixtures
        after_parse
      end
      @file.close if @file
    end
    
    def all_elements
      @elements
    end
    
    private
      def parse_fixtures
        fixtures_paths  = {'zena' => File.join("#{RAILS_ROOT}/test/sites",site,"#{table}.yml")}
        fixtures_bricks = ['zena']
        Bricks::Patcher.foreach_brick do |brick_path|
          brick_name = brick_path.split('/').last
          fixtures_paths[brick_name] = File.join(brick_path,'test','sites',site,"#{table}.yml")
          fixtures_bricks << brick_name
        end
        
        content = []
        fixtures_bricks.each do |brick|
          fixtures_path = fixtures_paths[brick]
          next unless File.exist?(fixtures_path)
          if brick == 'zena'
            content << "\n# ========== test/sites/#{site} ==========="
          else
            content << "\n# ========== [#{brick}]/test/sites/#{site}"
          end
          content << File.read(fixtures_path)
        end
        
        return if content == []
        
        
        content = content.join("\n") + "\n"
        
        # build simple hash to set/get defaults and other special values
        @elements[site] = elements = YAML::load(content.gsub(/<%.*?%>/m,''))
        
        # set defaults
        set_defaults
        
        definitions = []
        name = nil
        
        # Parse all content
        content.split("\n").each do |l|
          if l =~ /^([\w\.]+):/
            last_name = name
            name = $1
            # purge text in between fixtures
            if last_name
              parse_definitions(last_name, definitions)
            else
              # purge text in between fixtures
              definitions.each do |d|
                out d
              end
            end
            definitions = []
          else
            definitions << l
          end
        end
        
        if name
          parse_definitions(name, definitions)
        else
          # purge text in between fixtures
          definitions.each do |d|
            out d
          end
        end
        
      end
      
      def after_parse
      end
      
      def elements
        @elements[@site]
      end
      
      def set_defaults
        @defaults = elements.delete('DEFAULTS')
        @defaults ||= {}
        
        @defaults['site_id'] = Zena::FoxyParser::multi_site_id(site) if column_names.include?('site_id')
        
        elements.each do |n,v|
          unless v
            v = elements[n] = {}
          end
          v[:defaults_keys] = []
          column_names.each do |k|
            if k =~ /^(\w+)_id/
              k = $1
            end
            if !v.has_key?(k) && @defaults.has_key?(k)
              v[:defaults_keys] << k # so we know what to write out
              v[k] = @defaults[k]
            end
          end
          if column_names.include?('name') && !v.has_key?('name')
            v['name'] = n 
            v[:defaults_keys] << 'name'
          end
        end
      end
      
      def parse_definitions(name, definitions)
        return if name == 'DEFAULTS'
        @name = name
        
        insert_headers
        
        definitions.each do |l|
          if l =~ /^\s+([\w\_]+):\s*([^\s].*)$/
            k, v = $1, $2
            v = nil if v =~ /^\s*$/
            unless ignore_key?(k)
              out_pair(k,v)
            end
          else
            out l
          end
        end
        
      end
      
      def insert_headers
        out ""
        element = elements[name]
        
        if Zena::FoxyParser::multi_site_tables.include?(table)
          out "#{name}:"
        else
          out "#{site}_#{name}:"
        end
        
        if column_names.include?('id')
          if Zena::FoxyParser::multi_site_tables.include?(table)
            element['id'] = Zena::FoxyParser::multi_site_id(name)
          else
            element['id'] = Zena::FoxyParser::id(site, name)
          end  
          out_pair('id', element['id'])
        end
        
        out_pair('site_id', Zena::FoxyParser::multi_site_id(site)) if column_names.include?('site_id')
        
        id_keys.each do |k|
          insert_id(k)
        end
        
        multi_site_id_keys.each do |k|
          insert_multi_site_id(k)
        end
        
        element[:defaults_keys].each do |k|
          next if ignore_key?(k)
          out_pair(k, element[k])
        end
      end
      
      def out(res)
        unless @file
          # only open the file if we have things to write in it
          @file = File.open("#{RAILS_ROOT}/test/fixtures/#{table}.yml", 'wb')
          @file.puts "# Fixtures generated from content of 'sites' folder by #{self.class} (rake zena:build_fixtures)"
          @file.puts ""
          @file.puts self.class.prelude
        end
        @file.puts res
      end
      
      def out_pair(k,v)
        return if v.nil?
        out sprintf('  %-16s %s', "#{k}:", v.to_s =~ /^\s*$/ ? v.inspect : v.to_s)
      end
      
      def ignore_key?(k)
        (id_keys + multi_site_id_keys).include?(k)
      end
      
      def insert_id(key)
        return unless column_names.include?("#{key}_id")
        out_pair("#{key}_id", Zena::FoxyParser::id(site, elements[@name][key]))
      end
      
      def insert_multi_site_id(key)
        return unless column_names.include?("#{key}_id")
        out_pair("#{key}_id", Zena::FoxyParser::multi_site_id(elements[@name][key]))
      end
      
      def id_keys
        @id_keys ||= column_names.map {|n| n =~ /^(\w+)_id$/ ? $1 : nil }.compact - multi_site_id_keys - ['site']
      end
      
      def multi_site_id_keys
        ['user']
      end
  end
  
  class FoxyUsersParser < FoxyParser
    
    def insert_headers
      user  = elements[name]
      super
      out_pair('groups', user['groups']) if user['groups']
    end
    
    private
    
      def ignore_key?(k)
                 # use our built default
        super || ['groups'].include?(k)
      end
      
      def set_defaults
        super
        elements.each do |name,values|
          if groups = values['groups']
            values['groups'] = groups.split(',').map {|g| "#{site}_#{g.strip}"}.join(', ')
          end
        end
      end
  end
  
  class FoxyNodesParser < FoxyParser
    attr_reader :virtual_classes, :max_status, :publish_from, :zip_counter
    
    def initialize(table_name, opts = {})
      super
      @virtual_classes = opts[:virtual_classes].all_elements
      @max_status      = opts[:versions].max_status
      @publish_from    = opts[:versions].publish_from
      @zip_counter     = {}
      @versions        = {} # sub file generated by 'v_...' attributes
      @contents        = {} # sub content generated by 'c_...' attributes
    end
    
    private
      def set_defaults
        super
        # set publish_from, max_status, ...
        
        elements.each do |name, node|
          node.keys.each do |k|
            if k =~ /^v_/
              # need version defaults
              @defaults.each do |key,value|
                next unless key =~ /^v_/
                node[key] = value
              end
              break
            end
          end
          
          klass = node['class']
          if virtual_classes[site] && vc = virtual_classes[site][klass]
            node['vclass_id'] = Zena::FoxyParser::id(site,klass)
            node['type']  = eval(vc['real_class'])
            node['kpath'] = vc['kpath']
          elsif klass
            begin
              klass = eval(klass)
              node['kpath'] = klass.kpath
              node['type']  = klass
            rescue ArgumentError
              raise ArgumentError.new("[#{site} #{table} #{name}] unknown class '#{klass}'.")
            end
          else
            raise ArgumentError.new("[#{site} #{table} #{name}] missing 'class' attribute.")
          end
          
          node['publish_from'] = publish_from[site][name] || node['v_publish_from']
          
          if status = node['v_status']
            max_status[site][name] = Zena::Status[status.to_sym]
          end
          node['max_status'] = max_status[site][name] || (node['v_status'] ? Zena::Status[node['v_status'].to_sym] : nil)
          
          node['inherit'] = node['inherit'] ? 'yes' : 'no'
        end
        
        
        
        # set project, section, read/write/publish groups

        [['project',"nil", "parent['type'].kpath =~ /^\#{Project.kpath}/", "current['parent']"],
         ['section',"nil", "parent['type'].kpath =~ /^\#{Section.kpath}/", "current['parent']"],
         ['rgroup' ,"node['inherit'] == 'no'", "parent['inherit'] == 'no'", "parent['rgroup']"],
         ['wgroup' ,"node['inherit'] == 'no'", "parent['inherit'] == 'no'", "parent['wgroup']"],
         ['pgroup' ,"node['inherit'] == 'no'", "parent['inherit'] == 'no'", "parent['pgroup']"],
         ['skin' ,"node['inherit'] == 'no'", "parent['inherit'] == 'no'", "parent['skin']"],
         ].each do |key, next_if, parent_test, value|
          elements.each do |k,node|
            next if node[key] || eval(next_if)
            current = node
            name    = k
            res     = nil
            path_names = [k]
            while true
              if parent = elements[current['parent']]
                # has a parent
                if eval(parent_test)
                  # found
                  res = eval(value)
                  break
                elsif parent[key]
                  res = parent[key]
                  # found
                  break
                else
                  # move up
                  path_names << name
                  name    = current['parent']
                  current = parent
                end
              elsif current['parent']
                raise NameError.new("[#{site} #{k}] Bad parent name '#{current['parent']}' for node '#{name}'.")
              else
                # top node
                if key == 'project' || key == 'section'
                  res = current[key] = name
                else
                  raise NameError.new( "[#{site} #{k}] Reached top without finding '#{key}'.")
                end
                break
              end
            end
            if res
              path_names.each do |n|
                elements[n][key] = res
              end
            end
          end
        end
        
        # build fullpath
        elements.each do |k, node|
          make_paths(node, k)
        end
      end
      
      def make_paths(node, name)
        if !node['fullpath']
          if node['parent'] && parent = elements[node['parent']]
            node['fullpath'] = (make_paths(parent, node['parent']).split('/') + [node['name'] || name]).join('/')
            klass = if virtual_classes[site] && vc = virtual_classes[site][node['class']]
              vc['real_class']
            else
              node['class']
            end
            begin
              eval(klass).kpath =~ /^#{Page.kpath}/
              if node['custom_base']
                node['basepath'] = node['fullpath']
              else
                node['basepath'] = parent['basepath']
              end
            rescue NameError
              raise NameError.new("[#{site} #{table} #{name}] could not find class #{klass}.")
            end
          else
            node['basepath'] = ""
            node['fullpath'] = ""
          end
        end
        node['fullpath']
      end
      
      def insert_headers
        super
        node  = elements[name]
        # we compute 'zip' here so that the order of the file is kept
        @zip_counter[site] ||= 0
        if node['zip']
          if node['zip'] > @zip_counter[site]
            @zip_counter[site] = node['zip']
          end
        else
          @zip_counter[site] += 1
          node['zip'] = @zip_counter[site]
        end
        
        ['type','vclass_id','kpath', 'zip', 'max_status', 'publish_from', 'inherit',
         'rgroup_id', 'wgroup_id', 'pgroup_id', 'skin', 'fullpath', 'basepath'].each do |k|
          out_pair(k, node[k])
        end
      end
      
      def ignore_key?(k)
        super || ['class', 'skin', 'inherit', 'zip', 'fullpath', 'basepath'].include?(k)
      end
      
      def out_pair(k,v)
        if k.to_s =~ /^v_(.+)/
          # add key to default version
          version_key($1,v)
        elsif k.to_s =~ /^c_(.+)/
          # add key to content
          content_key($1,v)
        else
          super
        end
      end
      
      def version_key(key,value)
        
        @versions[site] ||= {}
        unless @versions[site][name]
          @versions[site][name] = version = {}
          version[:node] = node = elements[name]
          version['node_id'] = Zena::FoxyParser::id(site, name)
          # set defaults
          @defaults.each do |k,v|
            if k =~ /^v_(.+)/
              version[$1] = v
            end
          end
          version['publish_from'] ||= elements[name]['publish_from']
          version['status'] ||= elements[name]['max_status'] || Zena::Status[:pub]
          version['lang']   ||= elements[name]['ref_lang']
          version['site_id']  = Zena::FoxyParser::multi_site_id(site)
          version['number'] ||= 1
          
          if klass = elements[name]['type']
            if klass = klass.version_class.content_class
              if klass == ContactContent && !node['c_first_name']
                first_name, user_name = node['v_title'].split
                content_key('first_name', first_name)
                content_key('name', user_name) if user_name
              end
            end
          end
                
        end
        if key == 'status'
          value = Zena::Status[key.to_sym]
        end
        @versions[site][name][key] = value
      end
      
      def content_key(key,value)
        @contents[site] ||= {}
        klass = elements[name]['type']
        klass = klass.version_class.content_class
        @contents[site][klass] ||= {}
        unless @contents[site][klass][name]
          @contents[site][klass][name] = content = {}
          content[:node] = elements[name]
          content['site_id']  = Zena::FoxyParser::multi_site_id(site)
        end
        @contents[site][klass][name][key] = value
      end
      
      def after_parse
        super
        write_versions
        write_contents
      end
      
      def write_versions
        File.open("#{RAILS_ROOT}/test/fixtures/versions.yml", 'ab') do |file|
          file.puts "\n# ========== #{site} (generated from 'nodes.yml') ==========="
          file.puts ""
        
          if versions = @versions[site]
            versions.each do |name, version|
              file.puts ""
              node = version.delete(:node)
              version['id'] = Zena::FoxyParser::id(site, "#{name}_#{version['lang']}")
              version['lang'] ||= node['ref_lang']
              version['user_id'] ||= Zena::FoxyParser::multi_site_id(node['user'])
              version['type'] = node['type'].version_class
              file.puts "#{site}_#{name}:"
              version.each do |k,v|
                file.puts sprintf('  %-16s %s', "#{k}:", v.to_s =~ /^\s*$/ ? v.inspect : v.to_s)
              end
            end
          end
        end
      end
      
      def write_contents
        (@contents[site] || {}).each do |klass, contents|
          File.open("#{RAILS_ROOT}/test/fixtures/#{klass.table_name}.yml", 'ab') do |file|
            file.puts "\n# ========== #{site} (generated from 'nodes.yml') ==========="
            file.puts ""
            columns = klass.column_names
            contents.each do |name, content|
              file.puts ""
              node = content.delete(:node)
              content['id'] = Zena::FoxyParser::id(site, "#{name}_#{node['v_lang'] || node['ref_lang']}")
              content['version_id'] = content['id'] if columns.include?('version_id')
              content['node_id'] = node['id'] if columns.include?('node_id')
              file.puts "#{site}_#{name}:"
              content.each do |k,v|
                file.puts sprintf('  %-16s %s', "#{k}:", v.to_s =~ /^\s*$/ ? v.inspect : v.to_s)
              end
            end
          end
        end
      end
  end
  
  class FoxyVersionsParser < FoxyParser
    attr_reader :max_status, :publish_from
    
    def initialize(table_name, opts = {})
      super
      @max_status   = {}
      @publish_from = {}
    end
    
    private
      def set_defaults
        super
        
        @max_status[site]   = {}
        @publish_from[site] = {}
        elements.each do |k,v|
          # set status
          v['status'] = Zena::Status[v['status'].to_sym]
          @max_status[site][v['node']] ||= 0
          @max_status[site][v['node']] = v['status'] if v['status'] > @max_status[site][v['node']]
          # set publish_from
          @publish_from[site][v['node']] ||= v['publish_from']
          @publish_from[site][v['node']] = v['publish_from'] if v['publish_from'] && v['publish_from'] > @publish_from[site][v['node']]
        end
      end
      
      def insert_headers
        super
        out_pair('status', elements[name]['status']) if elements[name]['status']
      end
      
      def ignore_key?(k)
        super || ['status'].include?(k)
      end
      
  end
  
  class FoxySitesParser < FoxyParser
    private
      def multi_site_id_keys
        super + ['su', 'anon']
      end
  end
  
  class FoxyRelationsParser < FoxyParser
    attr_reader :virtual_classes
    
    def initialize(table_name, opts={})
      super
      @virtual_classes = opts[:virtual_classes].all_elements
    end
    
    def insert_headers
      super
      ['source_kpath', 'target_kpath'].each do |k|
        out_pair(k, elements[name][k])
      end
    end
    
    def ignore_key?(k)
      super || ['source_kpath', 'target_kpath', 'source', 'target'].include?(k)
    end
    
    
    private
      def set_defaults
        super
        
        elements.each do |name,rel|
          src = rel['source']
          trg = rel['target']
          if !src && !trg
            src, trg = name.split('_')
          end
          rel['source_kpath'] ||= get_kpath(src)
          rel['target_kpath'] ||= get_kpath(trg)
        end
      end
      
      def get_kpath(klass)
        if vc = virtual_classes[site][klass]
          vc['kpath']
        else
          eval(klass).kpath
        end
      end
    
  end
  
  class FoxyLinksParser < FoxyParser
    attr_reader :nodes
    
    def initialize(table_name, opts = {})
      super
      @nodes = opts[:nodes].all_elements
    end
    private
      def set_defaults
        super
        
        elements.each do |name,rel|
          if !rel['source'] && !rel['target']
            rel['source'], rel['target'] = name.split('_x_')
          end
          if !rel['relation']
            src = nodes[site][rel['source']]
            trg = nodes[site][rel['target']]
            if src && trg
              rel['relation'] = src['class'] + '_' + trg['class']
            end
          end
        end
      end
  end
  
  class FoxyGroupsUsersParser < FoxyParser
    attr_reader :nodes
    
    private
      def set_defaults
        super
        
        elements.each do |name,rel|
          if !rel['user'] && !rel['group']
            rel['user'], rel['group'] = name.split('_in_')
          end
        end
      end
  end
  
  class FoxyZipsParser < FoxyParser
    def initialize(table_name, opts = {})
      super
      @zip_counter = opts[:nodes].zip_counter
    end
    
    def run
      Dir.foreach("#{RAILS_ROOT}/test/sites") do |site|
        next if site =~ /^\./ || !File.directory?(File.join("#{RAILS_ROOT}/test/sites",site))
        out ""
        out "#{site}:"
        out_pair('site_id', Zena::FoxyParser::multi_site_id(site))
        out_pair('zip', @zip_counter[site])
      end
      @file.close if @file
    end
    
    private
      def find_max(elements)
        max = -1
        elements.each do |k,v|
          zip = Zena::FoxyParser::id(site, "#{k}_zip")
          if zip > max
            max = zip
          end
        end
        max
      end
  end
  
  class FoxyIformatsParser < FoxyParser
    private
      def insert_headers
        super
        out_pair('size', Iformat::SIZES.index(elements[name]['size'])) if elements[name]['size']
        out_pair('gravity', Iformat::GRAVITY.index(elements[name]['gravity'])) if elements[name]['gravity']
      end
      
      def ignore_key?(k)
        super || ['size', 'gravity'].include?(k)
      end
  end
  
  class FoxyCommentsParser < FoxyParser
    private
      def insert_headers
        super
        out_pair('status', Zena::Status[elements[name]['status'].to_sym]) if elements[name]['status']
        out_pair('reply_to', Zena::FoxyParser::id(site,elements[name]['reply_to'])) if elements[name]['reply_to']
      end
      
      def ignore_key?(k)
        super || ['status', 'reply_to'].include?(k)
      end
      
  end
  
  class FoxyParticipationsParser < FoxyParser
    private
      def insert_headers
        super
        out_pair('status', User::Status[elements[name]['status'].to_sym]) if elements[name]['status']
      end
      
      def ignore_key?(k)
        super || ['status'].include?(k)
      end
      
      def set_defaults
        super

        elements.each do |name,part|
          if !part['user'] && !part['site']
            part['user'], part['site'] = name.split('_in_')
            part['site'] ||= site
          end
          part['contact'] ||= part['user']
        end
      end
  end
end
