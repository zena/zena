require 'yaml'
require 'fileutils'

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
    
    # included at start of fixture file
    def self.prelude
      ""
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
        fixtures_path = File.join("#{RAILS_ROOT}/test/sites",site,"#{table}.yml")
        return unless File.exist?(fixtures_path)
        
        out "\n# ========== #{site} ==========="
        content = File.read(fixtures_path) + "\n"
        
        # build simple hash to set/get defaults and other special values
        content.gsub!(/<%.*?%>/m,'')
        @elements[site] = elements = YAML::load(content)
        
        # set defaults
        set_defaults
        
        definitions = []
        name = nil
        File.foreach(File.join("#{RAILS_ROOT}/test/sites",site,"#{table}.yml")) do |l|
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
        
        @defaults['site_id'] = ZenaTest::multi_site_id(site) if column_names.include?('site_id')
        
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
        
        if ZenaTest::multi_site_tables.include?(table)
          out "#{name}:"
        else
          out "#{site}_#{name}:"
        end
        
        if column_names.include?('id')
          if ZenaTest::multi_site_tables.include?(table)
            element['id'] = ZenaTest::multi_site_id(name)
          else
            element['id'] = ZenaTest::id(site, name)
          end  
          out_pair('id', element['id'])
        end
        
        out_pair('site_id', ZenaTest::multi_site_id(site)) if column_names.include?('site_id')
        
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
          @file.puts "# Fixtures generated from content of 'sites' folder by FoxyParser (rake zena:build_fixtures)"
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
        out_pair("#{key}_id", ZenaTest::id(site, elements[@name][key]))
      end
      
      def insert_multi_site_id(key)
        return unless column_names.include?("#{key}_id")
        out_pair("#{key}_id", ZenaTest::multi_site_id(elements[@name][key]))
      end
      
      def id_keys
        @id_keys ||= column_names.map {|n| n =~ /^(\w+)_id$/ ? $1 : nil }.compact - multi_site_id_keys - ['site']
      end
      
      def multi_site_id_keys
        ['user']
      end
  end
  FOXY_PARSER = {}
  
  class FoxyNodeParser < FoxyParser
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
            node['vclass_id'] = ZenaTest::id(site,klass)
            node['type']  = eval(vc['real_class'])
            node['kpath'] = vc['kpath']
          elsif klass
            node['type'] = eval(klass)
            begin
              klass = Module.const_get(klass)
              node['kpath'] = klass.kpath
            rescue NameError
              raise NameError.new("[#{site} #{table} #{name}] unknown class '#{klass}'.")
            end
          else
            raise NameError "[#{site} #{table} #{name}] missing 'class' attribute."
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
          version['node_id'] = ZenaTest::id(site, name)
          # set defaults
          @defaults.each do |k,v|
            if k =~ /^v_(.+)/
              version[$1] = v
            end
          end
          version['publish_from'] ||= elements[name]['publish_from']
          version['status'] ||= elements[name]['max_status'] || Zena::Status[:pub]
          version['lang']   ||= elements[name]['ref_lang']
          version['site_id']  = ZenaTest::multi_site_id(site)
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
          content['site_id']  = ZenaTest::multi_site_id(site)
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
              version['id'] = ZenaTest::id(site, "#{name}_#{version['lang']}")
              version['lang'] ||= node['ref_lang']
              version['user_id'] ||= ZenaTest::multi_site_id(node['user'])
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
              content['id'] = ZenaTest::id(site, "#{name}_#{node['v_lang'] || node['ref_lang']}")
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
  FOXY_PARSER['nodes'] = FoxyNodeParser
  
  class FoxyVersionParser < FoxyParser
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
  FOXY_PARSER['versions'] = FoxyVersionParser
  
  class FoxySiteParser < FoxyParser
    private
      def multi_site_id_keys
        super + ['su', 'anon']
      end
  end
  FOXY_PARSER['sites'] = FoxySiteParser
  
  
  class FoxyRelationParser < FoxyParser
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
  FOXY_PARSER['relations'] = FoxyRelationParser
  
  
  class FoxyLinkParser < FoxyParser
    attr_reader :nodes
    
    def self.prelude
      "dummy:\n  id: -1\n"
    end
    
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
  FOXY_PARSER['links'] = FoxyLinkParser
  
  
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
  FOXY_PARSER['groups_users'] = FoxyGroupsUsersParser
  
  class FoxyZipParser < FoxyParser
    def initialize(table_name, opts = {})
      super
      @zip_counter = opts[:nodes].zip_counter
    end
    
    def run
      Dir.foreach("#{RAILS_ROOT}/test/sites") do |site|
        next if site =~ /^\./
        out ""
        out "#{site}:"
        out_pair('site_id', ZenaTest::multi_site_id(site))
        out_pair('zip', @zip_counter[site])
      end
      @file.close if @file
    end
    
    private
      def find_max(elements)
        max = -1
        elements.each do |k,v|
          zip = ZenaTest::id(site, "#{k}_zip")
          if zip > max
            max = zip
          end
        end
        max
      end
  end
  FOXY_PARSER['zips'] = FoxyZipParser
  
  
  class FoxyIformatParser < FoxyParser
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
  FOXY_PARSER['iformats'] = FoxyIformatParser
  
  
  class FoxyCommentParser < FoxyParser
    private
      def insert_headers
        super
        out_pair('status', Zena::Status[elements[name]['status'].to_sym]) if elements[name]['status']
        out_pair('reply_to', ZenaTest::id(site,elements[name]['reply_to'])) if elements[name]['reply_to']
      end
      
      def ignore_key?(k)
        super || ['status', 'reply_to'].include?(k)
      end
      
  end
  FOXY_PARSER['comments'] = FoxyCommentParser
  
  
  class FoxyParticipationParser < FoxyParser
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
  FOXY_PARSER['participations'] = FoxyParticipationParser
end
  
namespace :zena do
  desc "Create a new site, parameters are PASSWORD, HOST, LANG"
  task :mksite => :environment do
    # 0. set host name
    unless host = ENV['HOST']
      puts "Please set HOST to the hostname for the new site. Aborting."
    else
      unless pass = ENV['PASSWORD']
        puts "Please set PASSWORD to the admin password for the new site. Aborting."
      else  
        ENV['LANG'] ||= 'en'
        host_path = "#{SITES_ROOT}/#{host}"
        if Site.find_by_host(host)
          puts "Host already exists in the database. Aborting."
        elsif File.exist?(host_path)
          puts "Path for host files exists (#{host_path}). Aborting."
        else
          site = Site.create_for_host(host, pass, :default_lang => ENV['LANG'])
          if site.new_record?
            puts "Could not create site ! Errors:"
            site.errors.each do |k,v|
              puts "[#{k}] #{v}"
            end
            puts "Aborting."
          else
            # 1. create directories and symlinks
            ['public', 'data', 'log'].each do |dir|
              FileUtils.mkpath("#{host_path}/#{dir}")
            end
      
            # FIXME: how do we keep favicon.ico and robots.txt in the root dir of a site ?
            # FIXME: ln should be to 'current' release, not calendar -> /var/zena/releases/20070511195642/public/calendar
            #        we could create a symlink in the sites dir to 'shared' -> /var/zena/current/public
            #        and then symlink with "#{host_path}/public/#{dir}" -> "../shared/public/#{dir}"
            #        OR we could symlink /var/zena/current/...
            ['calendar', 'images', 'javascripts', 'stylesheets', 'icons'].each do |dir|
              # FIXME: 'RAILS_ROOT' should be '/var/zena/current' and not '/var/zena/releases/20070632030330' !!!
              FileUtils.ln_s("#{RAILS_ROOT}/public/#{dir}", "#{host_path}/public/#{dir}")
            end
            
            puts "Site [#{host}] created."
          end
        end
      end
    end
  end
  
  desc "Rename a host"
  task :rename_host => :environment do
    # 0. set host name
    unless host = ENV['HOST']
      puts "Please set HOST to the hostname for the new site name. Aborting."
    else
      unless old_host = ENV['OLD_HOST']
        puts "Please set OLD_HOST to the hostname of the old site name. Aborting."
      else
        host_path = "#{SITES_ROOT}/#{old_host}"
        if !site = Site.find_by_host(old_host)
          puts "Old host does not exist in the database. Aborting."
        elsif Site.find_by_host(host)
          puts "New host already exist in the database. Aborting."
        elsif !File.exist?(host_path)
          puts "Path for host files does not exist (#{host_path}). Aborting."
        else
          site.host = host
          if !site.save
            puts "Could not change site name: #{site.errors.inspect}"
          else
            # move files
            FileUtils.mv(host_path, "#{SITES_ROOT}/#{host}")
            puts "Site '#{old_host}' renamed to '#{host}'."
          end
        end
      end
    end
  end
  
  desc "Remove all zafu compiled templates"
  task :clear_zafu do
    if File.exist?(SITES_ROOT)
      Dir.foreach(SITES_ROOT) do |site|
        next if site =~ /^\./
        FileUtils.rmtree(File.join(SITES_ROOT, site, 'zafu'))
      end
    end
  end
  
  desc "Remove all cached data" # FIXME: cachedPages db should be cleared to
  task :clear_cache => :environment do
    if File.exist?(SITES_ROOT)
      Dir.foreach(SITES_ROOT) do |site|
        next if site =~ /^\./ || !File.exist?(File.join(SITES_ROOT,site,'public'))
        Dir.foreach(File.join(SITES_ROOT,site,'public')) do |elem|
          next unless elem =~ /^(\w\w\.html|\w\w)$/
          FileUtils.rmtree(File.join(SITES_ROOT, site, 'public', elem))
        end
      end
      ['caches', 'cached_pages', 'cached_pages_nodes'].each do |tbl|
        Site.connection.execute "DELETE FROM #{tbl}"
      end
    end
  end
  
  desc "Create a backup of all data for a site"
  task :backup_site do
    unless host = ENV['HOST']
      puts "Please set HOST to the hostname for the site to backup. Aborting."
    else
      path = File.join(SITES_ROOT,ENV['HOST'])
      unless File.exist?(path)
        puts "Site does not exist in '#{SITES_ROOT}'"
      else
        folders = ['data'].map {|f| File.join(SITES_ROOT,f) }
        cmd = "tar czf #{path}_data.tgz #{folders.join(' ')}"
        puts cmd
        puts `#{cmd}`
      end
    end
  end
  
  task :full_backup => :environment do
    data_folders = Site.find(:all).map { |s| File.join(SITES_ROOT, s.data_path) }.reject { |p| !File.exist?(p) }
    cmd = "tar czf #{RAILS_ROOT}/sites_data.tgz #{data_folders.join(' ')}"
    puts cmd
    puts `#{cmd}`
  end
  
  desc "Migrate the database through scripts in db/migrate. Target specific brick and version with BRICK=x and VERSION=x"
  task :migrate => :environment do
    if ENV['VERSION'] || ENV['BRICK']
      ENV['BRICK']    ||= 'zena'
      # migrate specific bricks only
      mig_path = nil
      Dir.foreach('db/migrate') do |file|
        next if file =~ /^\./
        next unless File.stat("db/migrate/#{file}").directory?
        if file =~ /^[0-9-_]*#{ENV["BRICK"]}/
          mig_path = "db/migrate/#{file}"
          break
        end
      end
      if mig_path
        ActiveRecord::BricksMigrator.migrate(mig_path, ENV["BRICK"], ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
      else
        puts "Brick migrations must exist in db/migrate/BRICK"
      end
    else
      # migrate all to latest
      directories = []
      Dir.foreach('db/migrate') do |file|
        next if file =~ /^\./
        next unless File.stat("db/migrate/#{file}").directory?
        directories << file
      end
      directories.sort.each do |file|
        brick_name = file.sub(/^[0-9-_]*/,'')
        ActiveRecord::BricksMigrator.migrate("db/migrate/#{file}", brick_name, nil)
      end
      ActiveRecord::Migrator.migrate("db/migrate/", nil)
    end
    Rake::Task["db:schema:dump"].invoke if ActiveRecord::Base.schema_format == :ruby
  end
  
  desc 'Rebuild foxy fixtures for all sites'
  task :build_fixtures => :environment do
    ###
    tables = Node.connection.tables
    tables.delete('virtual_classes')
    tables.delete('versions')
    tables.delete('nodes')
    tables.delete('relations')
    tables.delete('zips')
    tables.delete('links')
             # 0.     # 1.                # need vc   # vers.  # nodes  # need vc.   # need nodes
    tables = tables + ['virtual_classes', 'versions', 'nodes', 'zips', 'relations', 'links']
    virtual_classes, versions, nodes = nil, nil, nil
    tables.each do |table|
      case table
      when 'virtual_classes'
        virtual_classes = Zena::FoxyParser.new(table)
        virtual_classes.run
      when 'versions'
        versions = Zena::FOXY_PARSER[table].new(table)
        versions.run
      when 'nodes'
        nodes = Zena::FOXY_PARSER[table].new(table, :versions => versions, :virtual_classes => virtual_classes)
        nodes.run
      when 'zips'
        Zena::FOXY_PARSER[table].new(table, :nodes => nodes).run
      when 'relations'
        Zena::FOXY_PARSER[table].new(table, :virtual_classes => virtual_classes).run
      when 'links'
        Zena::FOXY_PARSER[table].new(table, :nodes => nodes).run
      else
        (Zena::FOXY_PARSER[table] || Zena::FoxyParser).new(table).run
      end
    end
  end
  
  Rake::RDocTask.new do |rdoc|
       files = ['README', 'doc/README_FOR_APP', 'CREDITS', 'MIT-LICENSE', 'app/**/*.rb', 
                'lib/**/*.rb']
       rdoc.rdoc_files.add(files)
       rdoc.main = "doc/README_FOR_APP" # page to start on
       rdoc.title = "Zena Documentation"
       rdoc.template = "./doc/template/allison.rb"
       rdoc.rdoc_dir = 'doc/app' # rdoc output folder
       rdoc.options << '--line-numbers' << '--inline-source'
  end
  Rake::Task['zena:rdoc'].comment = "Create the rdoc documentation"
  
  namespace :test do
    desc 'Cleanup before testing'
    task :prepare => "db:test:prepare" do
      [File.join(SITES_ROOT, 'test.host', 'data'), File.join(SITES_ROOT, 'test.host', 'zafu')].each do |path|
        FileUtils::rmtree(path) if File.exist?(path)
      end
    end
  end
  
  Rake::TestTask.new(:test => "zena:test:prepare") do |t|
    t.libs << "test"
    # do not change the order in which these elements are loaded (adding 'lib/**/test/*_test.rb' fails)
    t.pattern = ['test/helpers/**/*_test.rb','test/unit/**/*_test.rb', 'lib/parser/test/*_test.rb', 'lib/query_builder/test/*_test.rb' 'test/functional/*_test.rb', 'test/integration/*_test.rb']
    t.verbose = true
  end
  Rake::Task['zena:test'].comment = "Run the tests in test/helpers and test/unit"
  
  namespace :fix do
    desc "Update all stored zafu to reflect change from 'news from project' syntax to 'news in project'. BACKUP BEFORE. DO NOT RUN."
    task :zafu_pseudo_sql => :environment do
      unless ENV['CODE'] == 'yes do it'
        puts "set CODE='yes do it' if you really want to run this (DO NOT RUN if unsure)."
      else
        {
          # 1. replace all finders like 'xyz from project' by 'xyz in project'
          ' from project' => ' in project',
          ' from section' => ' in section',
          ' from site' => ' in site',
          ' from  project' => ' in project',
          ' from  section' => ' in section',
          ' from  site' => ' in site',
          ' from   project' => ' in project',
          ' from   section' => ' in section',
          ' from   site' => ' in site',
          # 2. replace all finders like <:xyz from='project'... by <:xyz in='project'
          # 2.1 single quote
          " from='project'" => " in='project'",
          " from='section'" => " in='section'",
          " from='site'" => " in='site'",
          " from ='project'" => " in='project'",
          " from ='section'" => " in='section'",
          " from ='site'" => " in='site'",
          " from = 'project'" => " in='project'",
          " from = 'section'" => " in='section'",
          " from = 'site'" => " in='site'",
          " from= 'project'" => " in='project'",
          " from= 'section'" => " in='section'",
          " from= 'site'" => " in='site'",
          # 2.1 double quote
          ' from="project"' => ' in="project"',
          ' from="section"' => ' in="section"',
          ' from="site"' => ' in="site"',
          ' from ="project"' => ' in="project"',
          ' from ="section"' => ' in="section"',
          ' from ="site"' => ' in="site"',
          ' from = "project"' => ' in="project"',
          ' from = "section"' => ' in="section"',
          ' from = "site"' => ' in="site"',
          ' from= "project"' => ' in="project"',
          ' from= "section"' => ' in="section"',
          ' from= "site"' => ' in="site"',
          # kpath
          'NPD' => 'ND',
        }.each do |k,v|
          Version.connection.execute "UPDATE versions, nodes SET versions.text = REPLACE(text, #{Version.connection.quote(k)}, #{Version.connection.quote(v)}) WHERE versions.node_id = nodes.id AND nodes.kpath = 'NDTT'" # Template
        end
      end
    end
  end 
end


# ============ GetText ================
desc "Create mo-files for L10n" 
task :makemo do
  require 'gettext/utils'
  GetText.create_mofiles(true, "po", "locale")
end

desc "Update pot/po files to match new version." 
task :updatepo do 
  require 'gettext/utils'
  GetText::ActiveRecordParser.init(:use_classname => false, :db_mode => "development")
  GetText.update_pofiles('zena', Dir.glob("{app,lib}/**/*.{rb,rhtml,erb,rjs}"), Zena::VERSION::STRING)
end


module ActiveRecord
  class BricksMigrator < Migrator
    class << self
      def migrate(migrations_path, brick_name, target_version = nil)
        self.init_bricks_migration_table
        case
        when target_version.nil?, current_version(brick_name) < target_version
          up(migrations_path, brick_name, target_version)
        when current_version(brick_name) > target_version
          down(migrations_path, brick_name, target_version)
        when current_version(brick_name) == target_version
          return # You're on the right version
        end
      end

      def up(migrations_path, brick_name, target_version = nil)
        self.new(:up, migrations_path, brick_name, target_version).migrate
      end

      def down(migrations_path, brick_name, target_version = nil)
        self.new(:down, migrations_path, brick_name, target_version).migrate
      end

      def bricks_info_table_name
        Base.table_name_prefix + "bricks_info" + Base.table_name_suffix
      end

      def current_version(brick_name)
        begin
          ActiveRecord::Base.connection.select_one("SELECT version FROM #{bricks_info_table_name} WHERE brick = '#{brick_name}'")["version"].to_i
        rescue
          ActiveRecord::Base.connection.execute "INSERT INTO #{bricks_info_table_name} (brick, version) VALUES('#{brick_name}',0)"
          0
        end
      end

      def init_bricks_migration_table
        begin
          ActiveRecord::Base.connection.execute "CREATE TABLE #{bricks_info_table_name} (version #{Base.connection.type_to_sql(:integer)}, brick #{Base.connection.type_to_sql(:string)})"
        rescue ActiveRecord::StatementInvalid
          # Schema has been intialized
        end
      end
    end

    def initialize(direction, migrations_path, brick_name, target_version = nil)
      raise StandardError.new("This database does not yet support migrations") unless Base.connection.supports_migrations?
      @direction, @migrations_path, @brick_name, @target_version = direction, migrations_path, brick_name, target_version
      self.class.init_bricks_migration_table
    end

    def current_version
      self.class.current_version(@brick_name)
    end

    private

    def set_schema_version(version)
      Base.connection.update("UPDATE #{self.class.bricks_info_table_name} SET version = #{down? ? version.to_i - 1 : version.to_i} WHERE brick = '#{@brick_name}'")
    end
  end
end
