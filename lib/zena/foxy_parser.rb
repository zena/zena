require 'zena/loader/yaml_loader'

module Zena
  class FoxyParser
    attr_reader :column_names, :table, :elements, :site, :name, :defaults
    @@parser_for_table = {}

    class << self
      def id(site, key)
        return nil if key.blank?
        if key == 0 # special rgroup, wgroup, dgroup values...
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

      Dir.foreach("#{Zena::ROOT}/test/sites") do |site|
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
      def get_content(site, table)
        fixtures_paths  = {'zena' => File.join("#{Zena::ROOT}/test/sites",site,"#{table}.yml")}
        fixtures_bricks = ['zena']
        Bricks.foreach_brick do |brick_path|
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

        return nil if content == []
        all_content = content.join("\n") + "\n"

        ::ERB.new(content.join("\n") + "\n", nil, '-').result
      end

      def parse_fixtures
        return unless content = get_content(site, table)

        # Load hash to set/get defaults and transform special values
        @elements[site] = elements = YAML::load(content)

        # set defaults
        set_defaults

        between_obj = true
        # Parse all content
        content.split("\n").each do |l|
          if l =~ /^([\w\.]+):/
            # new object
            write_definitions($1, elements[$1])
            between_obj = false
          elsif l == ''
            # end of object
            between_obj = true
            out l
          elsif between_obj
            out l
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

        elements.each do |name, attributes|
          unless attributes
            attributes = elements[name] = {}
          end
          attributes[:header_keys] ||= []
          column_names.each do |k|
            if k =~ /^(\w+)_id/
              k = $1
            end
            if !attributes.has_key?(k) && @defaults.has_key?(k)
              attributes[:header_keys] << k # so we know what to write out
              attributes[k] = @defaults[k]
            end
          end
          if column_names.include?('name') && !attributes.has_key?('name')
            attributes['name'] = name
            attributes[:header_keys] << 'name'
          end
        end
      end

      def write_definitions(name, definitions)
        return if name == 'DEFAULTS'
        @name = name
        @inserted_keys = []

        insert_headers

        definitions.each do |key, value|
          next if key == :header_keys
          out_pair(key, value)
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

        element[:header_keys].each do |k|
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

      def out_pair(key, value)
        return if @inserted_keys.include?(key)
        return if ignore_key?(key)
        return if value.nil?
        @inserted_keys << key
        res = sprintf('  %-16s ', "#{key}:")
        if value.kind_of?(String)
          value.gsub!(%r{\[FILE:(.*?)\]}) do
            File.read("#{Zena::ROOT}/#{$1}")
          end
        end

        if value =~ /\n/
          res += "|\n    #{value.gsub("\n", "\n    ")}"
        elsif value.to_s =~ /[\{\[:]/
          res += value.inspect
        else
          res += value.to_s
        end
        out res
      end

      def ignore_key?(k)
        false
      end

      def insert_id(key)
        return unless column_names.include?("#{key}_id")
        @inserted_keys << key
        out_pair("#{key}_id", FoxyParser.id(site, elements[@name][key]))
      end

      def insert_multi_site_id(key)
        return unless column_names.include?("#{key}_id")
        @inserted_keys << key
        out_pair("#{key}_id", FoxyParser.multi_site_id(elements[@name][key]))
      end

      def id_keys
        @id_keys ||= column_names.map {|n| n =~ /^(\w+)_id$/ ? $1 : nil }.compact - multi_site_id_keys - ['site']
      end

      def multi_site_id_keys
        ['user']
      end

      def make_prop(prop)
        prop.each do |key, value|
          if value.kind_of?(String)
            value.gsub!(%r{\[FILE:(.*?)\]}) do
              File.read("#{Zena::ROOT}/#{$1}")
            end
          end
        end

        Property::Properties[prop].to_json
      end
  end

  class FoxyUsersParser < FoxyParser
    private
      def set_defaults
        super
        elements.each do |k, v|
          if groups = v['groups']
            v['groups'] = groups.split(',').map {|g| "#{site}_#{g.strip}"}.join(', ')
            v[:header_keys] << 'groups'
          end

          v[:header_keys] << 'contact'
          v['contact'] ||= k

          if v['status']
            v[:header_keys] << 'status'
            v['status'] = User::Status[v['status'].to_sym]
          end
        end
      end
  end

  class FoxyNodesParser < FoxyParser
    attr_reader :virtual_classes, :versions, :zip_counter

    def initialize(table_name, opts = {})
      super
      @virtual_classes = opts[:virtual_classes].all_elements
      @versions        = opts[:versions].versions
      @zip_counter     = {}
      @inline_versions = {} # sub file generated by 'v_...' attributes
      @inline_templates= {}
    end

    private
      def set_defaults
        super

        elements.each do |name, node|
          has_template = node['template']

          if template = node.delete('template')
            add_template(template, name)
          end

          if node.keys.include?('title') || node.keys.detect {|k| k =~ /^v_/}
            # need version defaults
            @defaults.each do |key,value|
              next unless key =~ /^v_/
              node[key] = value
            end
          end

          # FIXME: better filtering, in a hurry right now
          prop_field = nil
          %w{text title summary comment}.each do |k|
            if value = node.delete(k)
              unless prop_field
                prop_field = node['v_prop'] ||= {}
              end
              prop_field[k] = value
            end
          end

          node[:header_keys] += %w{type vclass_id kpath zip publish_from vhash inherit rgroup_id wgroup_id dgroup_id skin_id fullpath basepath}

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

          if records = versions[site][name]
            records.sort! do |a,b|
              case a['lang'] <=> b['lang']
              when 1
                1
              when -1
                -1
              else
                # descending status order
                b['status'] <=> a['status']
              end
            end
          else
            # build vhash
            records = [
              { 'id'           => Zena::FoxyParser::id(site, "#{name}_#{node['v_lang'] || node['ref_lang']}"),
                'publish_from' => node['v_publish_from'],
                'status'       => Zena::Status[node['v_status'].to_sym],
                'lang'         => node['v_lang'] || node['ref_lang']
              }
            ]
          end

          cached = Zena::Use::VersionHash.cached_values_from_records(records)
          node['publish_from'] = cached[:publish_from]
          node['vhash'] = cached[:vhash].to_json

          node['inherit'] = node['inherit'] ? 'yes' : 'no'
        end

        build_inherited_fields

        # build fullpath
        elements.each do |k, node|
          make_paths(node, k)
        end
      end

      def make_paths(node, name)
        if !node['fullpath']
          if node['parent'] && parent = elements[node['parent']]
            parent_fullpath = make_paths(parent, node['parent'])
            # Unquote content if it was an empty quoted string.
            parent_fullpath = '' if parent_fullpath == "''"
            node['fullpath'] = (parent_fullpath.split('/') + [node['name'] || name]).join('/')
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
            # If we do not quote the content, FoxyParser will insert NULL.
            node['basepath'] = "''"
            node['fullpath'] = "''"
          end
        end
        node['fullpath']
      end

      # set project, section, read/write/publish groups
      def build_inherited_fields
        [['project',"nil", "parent['type'].kpath =~ /^\#{Project.kpath}/", "current['parent']"],
         ['section',"nil", "parent['type'].kpath =~ /^\#{Section.kpath}/", "current['parent']"],
         ['rgroup' ,"node['inherit'] == 'no'", "parent['inherit'] == 'no'", "parent['rgroup']"],
         ['wgroup' ,"node['inherit'] == 'no'", "parent['inherit'] == 'no'", "parent['wgroup']"],
         ['dgroup' ,"node['inherit'] == 'no'", "parent['inherit'] == 'no'", "parent['dgroup']"],
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
      end

      def insert_headers
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

        super
      end


      def ignore_key?(k)
        super || ['class'].include?(k)
      end

      def out_pair(key, value)
        if key.to_s =~ /^v_(.+)/
          # add key to default version
          @inserted_keys << key
          version_key($1, value)
        else
          super
        end
      end

      def add_template(template, name)
        @inline_templates[site] ||= {}
        @inline_templates[site][name] = template
      end

      def version_key(key,value)

        @inline_versions[site] ||= {}
        unless @inline_versions[site][name]
          @inline_versions[site][name] = version = {}
          version[:node] = node = elements[name]
          version['node_id'] = Zena::FoxyParser::id(site, name)
          # set defaults
          @defaults.each do |k,v|
            if k =~ /^v_(.+)/
              version[$1] = v
            end
          end
          version['publish_from'] ||= elements[name]['publish_from']
          version['status'] ||= Zena::Status[:pub]
          version['lang']   ||= elements[name]['ref_lang']
          version['site_id']  = Zena::FoxyParser::multi_site_id(site)
          version['number'] ||= 1
        end
        if key == 'status'
          value = Zena::Status[key.to_sym]
        end
        @inline_versions[site][name][key] = value
      end

      def after_parse
        super
        write_versions
        write_template_indices
      end

      def write_versions
        #
        node_file = @file
          File.open("#{RAILS_ROOT}/test/fixtures/versions.yml", 'ab') do |file|
            @file = file

            if versions = @inline_versions[site]
              out "\n# ========== #{site} (generated from 'nodes.yml') ==========="
              out ""
              versions.each do |name, version|
                node = version.delete(:node)
                version['id'] = Zena::FoxyParser::id(site, "#{name}_#{version['lang']}")
                version['lang'] ||= node['ref_lang']
                version['user_id'] ||= Zena::FoxyParser::multi_site_id(node['user'])
                if prop = version.delete('prop')
                  version['properties'] = make_prop(prop) unless prop.blank?
                end

                out ""
                out "#{site}_#{name}:"
                @inserted_keys = []
                version.each do |k,v|
                  out_pair(k, v)
                end
              end
            end
          end
        @file = node_file
      end

      def write_template_indices
        #
        node_file = @file
          File.open("#{RAILS_ROOT}/test/fixtures/template_indices.yml", 'ab') do |file|
            @file = file

            if templates = @inline_templates[site]
              out "\n# ========== #{site} (generated from 'nodes.yml') ==========="
              out ""
              templates.each do |name, template|
                template['id'] = FoxyParser.id(site, name)
                template['node_id'] = FoxyParser.id(site, name)
                template['skin_id'] = FoxyParser.id(site, elements[name]['section'])
                template['site_id'] = FoxyParser.multi_site_id(site)
                version = @inline_versions[site][name]
                template['version_id'] = FoxyParser.id(site, "#{name}_#{version['lang']}")
                out ""
                out "#{site}_#{name}:"
                @inserted_keys = []
                template.each do |k,v|
                  out_pair(k, v)
                end
              end
            end
          end
        @file = node_file
      end
  end

  class FoxyVersionsParser < FoxyParser
    attr_reader :versions

    def initialize(table_name, opts = {})
      super
      @versions = {}
      @inline_attachments = {}
    end

    private
      def set_defaults
        super
        site_versions = @versions[site] = {}
        raw_nodes = YAML::load(get_content(site, 'nodes'))

        elements.each do |name, version|
          version[:header_keys] += %w{number lang status}

          version['status'] = Zena::Status[version['status'].to_sym]

          version['prop'] ||= {}
          version['prop']['title'] ||= raw_nodes[version['node']]['name'] || version['node']

          if prop = version.delete('prop')
            version['properties'] = make_prop(prop) unless prop.blank?
          end

          if filename = version.delete('filename')
            @inline_attachments[site] ||= {}
            @inline_attachments[site][name] = {
              'id' => FoxyParser::id(site, name),
              'filename' => filename,
              'user_id' => FoxyParser::id(site, version['user']),
            }
            version['attachment'] = name
          end

          node_versions = site_versions[version['node']] ||= []
          node_versions << version
        end
      end

      def after_parse
        super
        write_attachments
      end

      def write_attachments
        #
        node_file = @file
          File.open("#{RAILS_ROOT}/test/fixtures/attachments.yml", 'ab') do |file|
            @file = file

            if attachments = @inline_attachments[site]
              out "\n# ========== #{site} (generated from 'versions.yml') ==========="
              out ""
              attachments.each do |name, attachment|
                out ""
                out "#{site}_#{name}:"
                @inserted_keys = []
                attachment.each do |k,v|
                  out_pair(k, v)
                end
              end
            end
          end
        @file = node_file
      end
  end

  class FoxyAttachmentsParser < FoxyParser

    def initialize(table, opts={})
      super
    end

    private
      def set_defaults
        super
        raw_versions = YAML::load(get_content(site, 'versions'))
        elements.each do |k, attachment|
          version = attachment.delete('version')
          attachment['user']  = raw_versions[version]['user']
        end
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

    private
      def set_defaults
        super

        elements.each do |name,rel|
          rel[:header_keys] += ['source_kpath', 'target_kpath', 'source', 'target']
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
      Dir.foreach("#{Zena::ROOT}/test/sites") do |site|
        next if site =~ /^\./ || !File.directory?(File.join("#{Zena::ROOT}/test/sites",site))
        @inserted_keys = []
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
      def set_defaults
        super
        elements.each do |k, v|
          if v['size']
            v[:header_keys] << 'size'
            v['size'] = Iformat::SIZES.index(v['size'])
          end

          if v['gravity']
            v[:header_keys] << 'gravity'
            v['gravity'] = Iformat::GRAVITY.index(v['gravity'])
          end
        end
      end
  end

  class FoxyCommentsParser < FoxyParser
    private
      def set_defaults
        super
        elements.each do |k, v|
          if v['status']
            v[:header_keys] << 'status'
            v['status'] = Zena::Status[v['status'].to_sym]
          end

          if v['reply_to']
            v[:header_keys] << 'reply_to'
            v['reply_to'] =  Zena::FoxyParser::id(site, v['reply_to'])
          end
        end
      end
  end
end
