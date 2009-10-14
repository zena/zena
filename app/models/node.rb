=begin rdoc
A Node is the root class of all elements in the zena application. Class inheritance diagram:


FIXME: some parts are not correct (Partial, Task, Request, Milestone). Either correct this tree or add these classes.
Node (manages access and publication cycle)
  |
  +-- Page (web pages)
  |     |
  |     +--- Project (has it's own project_id. Can contain notes, collaborators, etc)
  |     |
  |     +--- Section (has it's own section_id = group of pages)
  |            |
  |            +--- Skin (theme: contains css, templates, etc)
  |
  +--- Document
  |      |
  |      +--- Image
  |      |
  |      +--- TextDocument       (for css, scripts)
  |             |
  |             +--- Partial     (uses the zafu templating language)
  |                    |
  |                    +--- Template  (entry for rendering)
  |
  +-- Note (date related information, event)
  |     |
  |     +--- Post (blog entry)
  |     |
  |     +--- Task
  |     |      |
  |     |      +--- Letter
  |     |      |
  |     |      +--- Request
  |     |             |
  |     |             +--- Bug
  |     |
  |     +--- Milestone
  |
  +-- Reference
        |
        +-- Contact (address, name, phone)

=== Node, Version and Content

The +nodes+ table only holds columns to secure the access. This table does not hold every possible data for every sub-class of Node. The text data is stored into the +versions+ table and any other specific content goes in its own table (+document_contents+ for example). This is an example of how an Image is stored :

Node         o-----------   Version   o---------  Content
dgroup_id                   title                 width
wgroup_id                   text                  height
user_id                     summary               content_type
...                         ...                   ...

=== Acessing version and content data

To ease the work to set/retrieve the data from the version and or content, we use some special notation. This notation abstracts this Node/Version/Content structure so you can use a version's attribute as if it was in the node directly.

TODO: DOC removed (was out of sync)

=== Dynamic attributes

The Version class uses dynamic attributes. These let you add any attribute you like to the versions (see DynAttribute for details). These attributes can be accessed by using the +d_+ prefix :

 @node.d_whatever  ===> @node.version.dyn[:whatever]

=== Attributes

Each node uses the following basic attributes:

Base attributes:

zip:: unique id (incremented in each site's scope).
name:: used to build the node's url when 'custom_base' is set. Used for document names.
site_id:: site to which this node belongs to.
parent_id:: parent node (every node except root is inserted in a unique place through this attribute).
user_id:: owner of the node.
ref_lang:: original node language.
created_at:: creation date.
updated_at:: modification date.
custom_base:: boolean value. When set to true, the node's url becomes it's fullpath. All it descendants will use this node's fullpath as their base url. See below for an example.
inherit:: inheritance mode (0=custom, 1=inherit, -1=private).

Attributes inherited from the parent:
section_id:: reference project (cannot be overwritten even if inheritance mode is custom).
rgroup_id:: id of the readers group.
wgroup_id:: id of the writers group.
dgroup_id:: id of the publishers group.
skin:: name of theSkin to use when rendering the pate ('theme').

Attributes used internally:
publish_from:: earliest publication date from all published versions.
kpath:: inheritance hierarchy. For example an Image has 'NPDI' (Node, Page, Document, Image), a Letter would have 'NNTL' (Node, Note, Task. Letter). This is used to optimize sql queries.
fullpath:: cached full path made of ancestors' names (<gdparent name>/<parent name>/<self name>).
basepath:: cached base path (the base path is used to build the url depending on the 'custom_base' flag).

=== Node url
A node's url is made of it's class and +zip+. For the examples below, this is our site tree:
 root
   |
   +--- projects (Page)
           |
           +--- worldTour (Project)
           |      |
           |      +--- photos (Page)
           |
           +--- music (Project)

The worldTour project's url would look like:
 /en/project21.html

The 'photos' url would be:
 /en/page23.html

When custom base is set (only for descendants of Page), worldTour url becomes its fullpath:
 /en/projects/worldTour

and the 'photos' url is now in the worldTour project's basepath:
 /en/projects/worldTour/page23.html

Setting 'custom_base' on a node should be done with caution as the node's zip is on longer in the url and when you move the node around, there is no way to find the new location from the old url. Custom_base should therefore only be used for nodes that are not going to move.
=end
class Node < ActiveRecord::Base

  include RubyLess::SafeClass
  safe_attribute :created_at, :updated_at, :event_at, :log_at, :publish_from, :basepath, :inherit

  # we use safe_method because the columns can be null, but the values are never null
  safe_method   :name => String, :kpath => String, :user_zip => Number, :parent_zip => Number,
                :project_zip => Number, :section_zip => Number, :skin => String, :ref_lang => String,
                :fullpath => String, :rootpath => String, :position => Number, :rgroup_id => Number,
                :wgroup_id => Number, :dgroup_id => Number, :custom_base => Boolean, :klass => String,
                :score => Number, :comments_count => Number,
                :custom_a => Number, :custom_b => Number,
                :m_text => String, :m_title => String, :m_author => String,
                :zip => Number
  # FIXME: remove 'zip' and use :id => {:class => Number, :method => 'zip'}
  # same with parent_zip, section_zip, etc...

  #attr_accessible    :version_content
  has_many           :discussions, :dependent => :destroy
  has_many           :links
  has_and_belongs_to_many :cached_pages
  belongs_to         :virtual_class, :foreign_key => 'vclass_id'
  belongs_to         :site
  before_validation  :node_before_validation  # run our 'before_validation' after 'secure'
  validates_presence_of :name
  validate           :validate_node
  before_create      :node_before_create
  before_save        :change_klass
  after_save         :spread_project_and_section
  after_save         :clear_children_fullpath
  after_create       :node_after_create
  attr_protected     :site_id, :zip, :id, :section_id, :project_id, :publish_from
  attr_protected     :site_id

  include Zena::Use::Dates::ModelMethods
  parse_date_attribute :event_at, :log_at

  include Zena::Use::NestedAttributesAlias::ModelMethods
  nested_attributes_alias %r{^v_(\w+)} => ['version']
  nested_attributes_alias %r{^c_(\w+)} => ['version', 'content']
  nested_attributes_alias %r{^d_(\w+)} => ['version', 'dyn']

  zafu_context       :author => "Contact", :parent => "Node",
                     :project => "Project", :section => "Section",
                     :real_project => "Project", :real_section => "Section",
                     :user => "User",
                     :version => "Version", :comments => ["Comment"],
                     :data   => {:node_class => ["DataEntry"], :data_root => 'node_a'},
                     :data_a => {:node_class => ["DataEntry"], :data_root => 'node_a'},
                     :data_b => {:node_class => ["DataEntry"], :data_root => 'node_b'},
                     :data_c => {:node_class => ["DataEntry"], :data_root => 'node_c'},
                     :data_d => {:node_class => ["DataEntry"], :data_root => 'node_d'}

  extend  Zena::Acts::SecureNode
  extend  Zena::Acts::Multiversion
  include Zena::Use::Relations::ModelMethods

  acts_as_secure_node
  acts_as_multiversioned
  use_node_query

  @@native_node_classes = {'N' => self}
  @@unhandled_children  = []
  class << self

    # needed for compatibility with virtual classes
    alias create_instance create
    alias new_instance new

    def inherited(child)
      super
      @@unhandled_children << child
    end

    # Return the list of (kpath,subclasses) for the current class.
    def native_classes
      # this is to make sure subclasses are loaded before the first call
      [Note,Page,Project,Section,Reference,Contact,Document,Image,TextDocument,Skin,Template]
      while child = @@unhandled_children.pop
        @@native_node_classes[child.kpath] = child
      end
      @@native_node_classes.reject{|kpath,klass| !(kpath =~ /^#{self.kpath}/) }
    end

    # check inheritance chain through kpath
    def kpath_match?(kpath)
      self.kpath =~ /^#{kpath}/
    end

    # Class list to which this class can change to
    def change_to_classes_for_form
      classes_for_form(:class => 'Node', :without => 'Document, Contact')
    end

    # List of classes that a node can change to.
    def allowed_change_to_classes
      change_to_classes_for_form.map {|k,v| v}
    end

    # FIXME: how to make sure all sub-classes of Node are loaded before this is called ?
    def classes_for_form(opts={})
      if klass = opts.delete(:class)
        if klass = get_class(klass)
          klass.classes_for_form(opts)
        else
          return ['', ''] # bad class
        end
      else
        all_classes(opts).map{|a,b| [a[0..-1].sub(/^#{self.kpath}/,'').gsub(/./,'  ') + b.to_s, b.to_s] } # white spaces are insecable spaces (not ' ')
      end
    end

    # FIXME: how to make sure all sub-classes of Node are loaded before this is called ?
    def kpaths_for_form(opts={})
      all_classes(opts).map{|a,b| [a[1..-1].gsub(/./,'  ') + b.to_s, a.to_s] } # white spaces are insecable spaces (not ' ')
    end

    def all_classes(opts={})
      virtual_classes = VirtualClass.find(:all, :conditions => ["site_id = ? AND create_group_id IN (?) AND kpath LIKE '#{self.kpath}%'", current_site[:id], visitor.group_ids])
      classes = (virtual_classes.map{|r| [r.kpath, r.name]} + native_classes.to_a).sort{|a,b| a[0] <=> b[0]}
      if opts[:without]
        reject_kpath =  opts[:without].split(',').map(&:strip).map {|name| Node.get_class(name) }.compact.map { |kla| kla.kpath }.join('|')
        classes.reject! {|k,c| k =~ /^#{reject_kpath}/ }
      end
      classes
    end

    # Return class or virtual class from name.
    def get_class(rel, opts={})
      class_name = rel.singularize.camelize # mushroom_types ==> MushroomType
      begin
        klass = Module.const_get(class_name)
        raise NameError unless klass.ancestors.include?(Node)
      rescue NameError
        # find the virtual class
        if opts[:create]
          klass = VirtualClass.find(:first, :conditions=>["site_id = ? AND create_group_id IN (?) AND name = ?",current_site[:id], visitor.group_ids, class_name])
        else
          klass = VirtualClass.find(:first, :conditions=>["site_id = ? AND name = ?",current_site[:id], class_name])
        end
      end
      klass
    end

    # Return a new object of the class name or nil if the class name does not exist.
    def new_from_class(rel)
      if k = get_class(rel, :create => true)
        k.new
      else
        nil
      end
    end

    def get_class_from_kpath(kp)
      native_classes[kp] || VirtualClass.find(:first, :conditions=>["site_id = ? AND kpath = ?",current_site[:id], kp])
    end

    # Find a node's attribute based on a pseudo (id or path). Used by zazen to create a link for ""::art or "":(people/ant) for example.
    def translate_pseudo_id(id, sym = :id, base_node = nil)
      if id.to_s =~ /\A(-?)(\d+)\Z/
        # zip
        # FIXME: this is not secure
        res = Zena::Db.fetch_row("SELECT #{sym} FROM nodes WHERE site_id = #{current_site[:id]} AND zip = '#{$2}'")
        res ? ($1.blank? ? res.to_i : -res.to_i) : nil
      elsif node = find_node_by_pseudo(id,base_node)
        node[sym]
      else
        nil
      end
    end

    # Find a node based on a query shortcut. Used by zazen to create a link for ""::art for example.
    def find_node_by_pseudo(id, base_node = nil)
      raise Zena::AccessViolation if self.scoped_methods == []
      str = id.to_s
      if str =~ /\A\d+\Z/
        # zip
        find_by_zip(str)
      elsif str =~ /\A:?([0-9a-zA-Z ]+)(\+*)\Z/
        offset = $2.to_s.size
        find(:first, Node.match_query($1.gsub('-',' '), :offset => offset))
      elsif path = str[/\A\(([^\)]*)\)\Z/,1]
        if path[0..0] == '/'
          find_by_path(path[1..-1])
        elsif base_node
          find_by_path(path.abs_path(base_node.fullpath))
        else
          # do not use (path) pseudo when there is no base_node (during create_or_update_node for example).
          # FIXME: path pseudo is needed for links... and it should be done here (egg and hen problem)
          nil
        end
      end
    end

    # def attr_public?(attribute)
    #   if attribute.to_s =~ /(.*)_zips?$/
    #     return true if self.ancestors.include?(Node) && RelationProxy.find_by_role($1.singularize)
    #   end
    #   super
    # end

    def create_or_update_node(new_attributes)
      attributes = transform_attributes(new_attributes)
      unless attributes['name'] && attributes['parent_id']
        node = Node.new
        node.errors.add('name', "can't be blank") unless attributes['name']
        node.errors.add('parent_id', "can't be blank") unless attributes['parent_id']
        return node
      end

      begin
        klass = Node.get_class(attributes['klass'] || 'Node')
        klass = klass.real_class if klass.kind_of?(VirtualClass)
      rescue NameError
        klass = Node
      end

      # FIXME: remove 'with_exclusive_scope' once scopes are clarified and removed from 'secure'
      node = klass.send(:with_exclusive_scope) do
        klass.find(:first, :conditions => ['site_id = ? AND name = ? AND parent_id = ?',
                                          current_site[:id], attributes['name'].url_name, attributes['parent_id']])
      end

      if node
        visitor.visit(node) # secure
        # TODO: class ignored (could be used to transform from one class to another...)
        attributes.delete('class')
        attributes.delete('klass')
        updated_date = node.updated_at
        node.update_attributes(attributes)

        if updated_date != node.updated_at
          node[:create_or_update] = 'updated'
        else
          node[:create_or_update] = 'same'
        end
      else
        node = create_node(new_attributes)
        node[:create_or_update] = 'new'
      end

      node
    end

    # TODO: cleanup and rename with something indicating the attrs cleanup that this method does.
    def create_node(new_attributes)
      attributes = transform_attributes(new_attributes)

      # the way this works here and in do_update_attributes is not good
      publish_after_save = (attributes.delete('v_status').to_i == Zena::Status[:pub])

      # TODO: replace this hack with a proper class method 'secure' behaving like the
      # instance method. It would get the visitor and scope from the same hack below.
      scope   = self.scoped_methods[0] || {}

      klass_name   = attributes.delete('class') || attributes.delete('klass') || 'Page'
      unless klass = get_class(klass_name, :create => true)
        node = Node.new
        node.instance_eval { @attributes = attributes }
        node.errors.add('klass', 'invalid')
        # This is to show the klass in the form seizure
        node.instance_variable_set(:@klass, klass_name.to_s)
        def node.klass; @klass; end
        return node
      end

      node = if klass != self
        # FIXME: remove 'with_exclusive_scope' once scopes are clarified and removed from 'secure'
        klass.send(:with_exclusive_scope, scope) { klass.create_instance(attributes) }
      else
        self.create_instance(attributes)
      end

      node.publish if publish_after_save
      node
    end

    # Create new nodes from the data in a folder or archive.
    def create_nodes_from_folder(opts)
      # TODO: all this method needs cleaning, it's a mess.
      return [] unless (opts[:folder] || opts[:archive]) && (opts[:parent] || opts[:parent_id])
      scope = self.scoped_methods[0] || {}
      parent_id = opts[:parent_id] || opts[:parent][:id]
      folder    = opts[:folder]
      defaults  = (opts[:defaults] || {}).stringify_keys
      klass     = opts[:klass] || "Page"
      res       = {}

      # create from archive
      unless folder
        archive = opts[:archive]
        n       = 0
        while true
          folder = File.join(RAILS_ROOT, 'tmp', sprintf('%s.%d.%d', 'import', $$, n))
          break unless File.exists?(folder)
        end

        begin
          FileUtils::mkpath(folder)

          if archive.kind_of?(StringIO)
            filename = archive.original_filename
            tempf = Tempfile.new(archive.original_filename)
            File.open(tempf.path, 'wb') { |f| f.syswrite(archive.read) }
            archive = tempf
          else
            filename = archive.original_filename
          end

          # extract file in this temporary folder.
          # FIXME: is there a security risk here ?
          if filename =~ /\.tgz$/
            `tar -C '#{folder}' -xz < '#{archive.path}'`
          elsif filename =~ /\.tar$/
            `tar -C '#{folder}' -x < '#{archive.path}'`
          elsif filename =~ /\.zip$/
            `unzip -d '#{folder}' '#{archive.path}'`
          elsif filename =~ /(.*)(\.gz|\.z)$/
            `gzip -d '#{archive.path}' -c > '#{folder}/#{$1.gsub("'",'')}'`
          else
            # FIXME: send errors back
            puts "BAD #{archive.inspect}"
          end
          res = create_nodes_from_folder(:folder => folder, :parent_id => parent_id, :defaults => defaults, :klass => klass)
        ensure
          FileUtils::rmtree(folder)
        end
        return res
      end

      entries = Dir.entries(folder).reject { |f| f =~ /^([\._~]|[^\w])/ }.sort
      index  = 0

      while entries[index]
        type = current_obj = sub_folder = document_path = nil
        versions = []
        filename = entries[index]

        path     = File.join(folder, filename)

        if File.stat(path).directory?
          type   = :folder
          name   = filename
          sub_folder = path
          attrs = defaults.dup
        elsif filename =~ /^(.+?)(\.\w\w|)(\.\d+|)\.zml$/  # bird.jpg.en.zml
          # node content in yaml
          type   = :node
          name   = "#{$1}#{$4}"
          lang   = $2.blank? ? nil : $2[1..-1]

          # no need for base_node (this is done after all with parse_assets in the controller)
          attrs  = defaults.merge(get_attributes_from_yaml(path))
          attrs['name']     = name
          attrs['v_lang']   = lang || attrs['v_lang'] || visitor.lang
          versions << attrs
        elsif filename =~ /^((.+?)\.(.+?))(\.\w\w|)(\.\d+|)$/ # bird.jpg.en
          type   = :document
          name   = $1
          attrs  = defaults.dup
          lang   = $4.blank? ? nil : $4[1..-1]
          attrs['v_lang'] = lang || attrs['v_lang'] || visitor.lang
          attrs['c_ext']  = $3
          document_path   = path
        end

        index += 1
        while entries[index] =~ /^#{name}(\.\w\w|)(\.\d+|)\.zml$/ # bird.jpg.en.zml
          lang   = $1.blank? ? visitor.lang : $1[1..-1]
          path   = File.join(folder,entries[index])

          # we have a zml file. Create a version with this file
          # no need for base_node (this is done after all with parse_assets in the controller)
          attrs = defaults.merge(get_attributes_from_yaml(path))
          attrs['name']     = name
          attrs['v_lang'] ||= lang
          versions << attrs

          index += 1
        end

        if versions.empty?
          if type == :folder
            # minimal node for a folder
            attrs['name']     = name
            attrs['v_lang'] ||= lang
            attrs['class']    = klass
            versions << attrs
          elsif type == :document
            # minimal node for a document
            attrs['name']     = name
            attrs['v_lang'] ||= lang
            versions << attrs
          end
        end

        new_object = false
        versions.each do |attrs|
          # FIXME: same lang: remove before update current_obj.remove if current_obj.v_lang == attrs['v_lang'] && current_obj.v_status != Zena::Status[:red]
          # FIXME: current_obj.publish if attrs['v_status'].to_i == Zena::Status[:pub]
          if type == :document
            attrs['name' ] = attrs['name'].split('.')[0..-2].join('.')
            if document_path
              attrs['c_ext'] ||= document_path.split('.').last
              # file
              insert_zafu_headings = false
              if opts[:parent_class] == 'Skin' && ['html','xhtml'].include?(attrs['c_ext']) && attrs['name'] == 'index'
                attrs['c_ext'] = 'zafu'
                attrs['name']  = 'Node'
                insert_zafu_headings = true
              end

              ctype = EXT_TO_TYPE[attrs['c_ext']]
              ctype = ctype ? ctype[0] : "application/octet-stream"
              attrs['c_content_type'] = ctype


              File.open(document_path) do |file|
                (class << file; self; end;).class_eval do
                  alias local_path path if defined?(:path)
                  alias o_read read
                  define_method(:original_filename) { filename }
                  define_method(:content_type) { ctype }
                  define_method(:read) do
                    if insert_zafu_headings
                      o_read.sub(%r{</head>},"  <r:stylesheets/>\n  <r:javascripts/>\n  <r:uses_datebox/>\n</head>")
                    else
                      o_read
                    end
                  end
                end
                current_obj = create_or_update_node(attrs.merge(:c_file => file, :klass => 'Document', :_parent_id => parent_id))
              end
              document_path = nil
            else
              current_obj = create_or_update_node(attrs.merge(:_parent_id => parent_id, :klass => 'Document'))
            end
          else
            # :folder, :node
            current_obj = create_or_update_node(attrs.merge(:_parent_id => parent_id))
          end
          new_object = new_object || current_obj.instance_variable_get(:@new_record_before_save)
        end
        current_obj.instance_variable_set(:@new_record_before_save, new_object)

        current_obj.instance_variable_set(:@versions_count, versions.size)
        res[current_obj[:id].to_i] = current_obj

        res.merge!(create_nodes_from_folder(:folder => sub_folder, :parent_id => current_obj[:id], :defaults => defaults, :parent_class => opts[:klass])) if sub_folder && !current_obj.new_record?
      end
      res
    end

    def find_by_zip(zip)
      node = find(:first, :conditions=>"zip = #{zip.to_i}")
      raise ActiveRecord::RecordNotFound unless node
      node
    end

    # Find a node by it's full path. Cache 'fullpath' if found.
    def find_by_path(path)
      return nil unless scope = scoped_methods[0]
      return nil unless scope[:find]   # not secured find. refuse.
      node = self.find_by_fullpath(path)
      if node.nil?
        path = path.split('/')
        last = path.pop
        # FIXME: remove 'with_exclusive_scope' once scopes are clarified and removed from 'secure'
        Node.send(:with_exclusive_scope) do
          node = Node.find(current_site[:root_id])
          path.each do |p|
            raise ActiveRecord::RecordNotFound unless node = Node.find_by_name_and_parent_id(p, node[:id])
          end
        end
        raise ActiveRecord::RecordNotFound unless node = self.find_by_name_and_parent_id(last, node[:id])
        path << last
        node.fullpath = path.join('/')
        # bypass callbacks here
        Node.connection.execute "UPDATE #{Node.table_name} SET fullpath='#{path.join('/').gsub("'",'"')}' WHERE id='#{node[:id]}'"
      end
      node
    end

    # Paginate found results. Returns [previous_page, collection, next_page]. You can specify page and items per page in the query hash :
    #  :page => 1, :per_page => 20. This should be wrapped into a secure scope.
    def find_with_pagination(count, opts)
      previous_page, collection, next_page, count_all = nil, [], nil, nil
      per_page = (opts.delete(:per_page) || 20).to_i
      page     = opts.delete(:page) || 1
      page     = page > 0 ? page.to_i : 1
      offset   = (page - 1) * per_page

      if opts[:group]
        count_select  = "DISTINCT #{opts[:group]}"
      else
        count_select  = opts.delete(:count) || 'nodes.id'
      end

      # FIXME: why do we need 'exclusive scope' here ?
      with_exclusive_scope(self.scoped_methods[0] || {}) do
        count_all = count(opts.merge( :select  => count_select, :order => nil, :group => nil ))
        if count_all > offset
          collection = find(count, opts.merge(:offset => offset, :limit => per_page))
          if count_all > (offset + per_page)
            next_page = page + 1
          end
          previous_page = page > 1 ? (page - 1) : nil
        else
          # offset too big, previous page = last page
          previous_page = page > 1 ? ((count_all + per_page - 1) / per_page) : nil
        end
      end
      [previous_page, collection, next_page, count_all]
    end

    # Return a hash to do a fulltext query.
    def match_query(query, opts={})
      node = opts.delete(:node)
      if query == '.' && node
        return opts.merge(
          :conditions => ["parent_id = ?",node[:id]],
          :order  => 'name ASC' )
      elsif !query.blank?
        if RAILS_ENV == 'test'
          match = sanitize_sql(["nodes.name LIKE ?", "#{query}%"])
          select = "nodes.*, #{match} AS score"
        else
          match  = sanitize_sql(["MATCH (vs.title,vs.text,vs.summary) AGAINST (?) OR nodes.name LIKE ?", query, "#{opts[:name_query] || query.url_name}%"])
          select = sanitize_sql(["nodes.*, MATCH (vs.title,vs.text,vs.summary) AGAINST (?) + (5 * (nodes.name LIKE ?)) AS score", query, "#{query}%"])
        end
        return opts.merge(
          :select => select,
          :joins  => "INNER JOIN versions AS vs ON vs.node_id = nodes.id AND vs.status >= #{Zena::Status[:pub]}",
          :conditions => match,
          :group      => "nodes.id",
          :order  => "score DESC, zip ASC")
      else
        # error
        return opts.merge(:conditions => '0')
      end
    end

    # FIXME: Where is this used ?
    def class_for_relation(rel)
      case rel
      when 'author'
        User
      when 'traductions'
        Version
      when 'versions'
        Version
      else
        Node
      end
    end

    def plural_relation?(rel)
      rel = rel.split(/\s/).first
      if ['root', 'parent', 'self', 'children', 'documents_only', 'all_pages'].include?(rel) || Node.get_class(rel)
        rel.pluralize == rel
      elsif rel =~ /\A\d+\Z/
        false
      else
        relation = RelationProxy.find_by_role(rel.singularize)
        return rel =~ /s$/ unless relation
        relation.target_role == rel.singularize ? !relation.target_unique : !relation.source_unique
      end
    end

    # Translate attributes from the visitor's reference to the application.
    # This method translates dates, zazen shortcuts and zips and returns a stringified hash.
    def transform_attributes(new_attributes, base_node = nil)
      res = {}
      res['parent_id'] = new_attributes[:_parent_id] if new_attributes[:_parent_id] # real id set inside zena.

      attributes = new_attributes.stringify_keys

      if attributes['copy'] || attributes['copy_id']
        copy_node = attributes.delete('copy')
        copy_node ||= Node.find_by_zip(attributes.delete('copy_id'))
        attributes = copy_node.replace_attributes_in_values(attributes)
      end

      if !res['parent_id'] && p = attributes['parent_id']
        res['parent_id'] = Node.translate_pseudo_id(p, :id, base_node) || p
      end

      attributes.keys.each do |key|
        next if ['_parent_id', 'parent_id'].include?(key)

        if ['rgroup_id', 'wgroup_id', 'dgroup_id'].include?(key)
          res[key] = Group.translate_pseudo_id(attributes[key], :id) || attributes[key]
        elsif ['rgroup', 'wgroup', 'dgroup'].include?(key)
          res["#{key}_id"] = Group.translate_pseudo_id(attributes[key], :id) || attributes[key]
        elsif ['user_id'].include?(key)
          res[key] = User.translate_pseudo_id(attributes[key], :id) || attributes[key]
        elsif ['date'].include?(key)
          # FIXME: this is a temporary hack because date in links do not support timezones/formats properly
          if attributes[key].kind_of?(Time)
            res[key] = attributes[key]
          elsif attributes[key]
            # parse date
            res[key] = attributes[key].to_utc("%Y-%m-%d %H:%M:%S")
          end
        elsif key =~ /^(\w+)_id$/
          if key[0..1] == 'd_'
            res[key] = Node.translate_pseudo_id(attributes[key], :zip, base_node) || attributes[key]
          else
            res[key] = Node.translate_pseudo_id(attributes[key],  :id, base_node) || attributes[key]
          end
        elsif key =~ /^(\w+)_ids$/
          # Id list. Bad ids are removed.
          values = attributes[key].kind_of?(Array) ? attributes[key] : attributes[key].split(',')
          if key[0..1] == 'd_'
            values.map! {|v| Node.translate_pseudo_id(v, :zip, base_node) }
          else
            values.map! {|v| Node.translate_pseudo_id(v,  :id, base_node) }
          end
          res[key] = values.compact
        elsif key == 'file'
          unless attributes[key].blank?
            res[key] = attributes[key]
          end
        elsif attributes[key].kind_of?(Hash)
          res[key] = transform_attributes(attributes[key], base_node)
        else
          # translate zazen
          value = attributes[key]
          if value.kind_of?(String)
            # FIXME: ignore if 'v_text' of a TextDocument...
            res[key] = ZazenParser.new(value,:helper=>self).render(:translate_ids=>:zip, :node=>base_node)
          else
            res[key] = value
          end
        end
      end

      res
    end

    def get_attributes_from_yaml(filepath, base_node = nil)
      attributes = YAML::load( File.read( filepath ) )
      attributes.delete(:_parent_id)
      transform_attributes(attributes, base_node)
    end

    def safe_method_type(signature)
      if signature.size > 1
        RubyLess::SafeClass.safe_method_type_for(self, signature)
      else
        method = signature.first
        # if model_names = nested_model_names_for_alias(method)
        #   # ...
        # end
        case method[0..1]
        when 'v_'
          method = method[2..-1]
          if type = version_class.safe_method_type([method])
            type.merge(:method => "version.#{type[:method]}")
          else
            # might be readable by sub-classes
            # what is the expected return type ?
            {:method => "version.safe_read(#{method.inspect})", :nil => true, :class => String}
          end
        when 'c_'
          method = method[2..-1]
          klass = version_class.content_class
          if klass && type = klass.safe_method_type([method])
            type.merge(:method => "version.content.#{type[:method]}")
          else
            {:method => "version.safe_content_read(#{method.inspect})", :nil => true, :class => String}
          end
        when 'd_'
          {:method => "version.dyn[#{method[2..-1].inspect}]", :nil => true, :class => String}
        else
          if method =~ /^(.+)_((id|zip|status|comment)(s?))\Z/ && !instance_methods.include?(method)
            {:method => "rel[#{$1.inspect}].try(:other_#{$2})", :nil => true, :class => ($4.blank? ? Number : [Number])}
          else
            RubyLess::SafeClass.safe_method_type_for(self, signature)
          end
        end
      end
    end

    # Return a safe string to access node attributes in compiled templates and compiled sql.
    def zafu_attribute(node, attribute)
      if node.kind_of?(String)
        raise Exception.new("You should use safe_method_type...")
      else
        node.safe_read(attribute)
      end
    end


    def auto_create_discussion
      false
    end
  end

  # TODO: remove when :inverse_of works.
  def versions_with_secure(*args)
    proxy = versions_without_secure(*args)
    if frozen?
      proxy = []
    elsif proxy.loaded?
      proxy.each do |v|
        v.node = self
      end
    end
    proxy
  end
  alias_method_chain :versions, :secure

  # Additional security so that unsecure finders explode when trying to update/save or follow relations.
  def visitor
    return @visitor if @visitor
    # We need to be more tolerant during object creation since 'v_foo' can be
    # set before 'visitor' and we need visitor.lang when creating versions.
    return Thread.current.visitor if new_record?
    raise Zena::RecordNotSecured.new("Visitor not set, record not secured.")
  end

  # Return an attribute if it is safe (RubyLess allowed). Return nil otherwise.
  # This is mostly used when the zafu compiler cannot decide whether a method is safe or not at compile time.
  def safe_read(attribute)
    case attribute[0..1]
    when 'v_'
      version.safe_read(attribute[2..-1])
    when 'c_'
      version.safe_content_read(attribute[2..-1])
    when 'd_'
      version.dyn[attribute[2..-1]]
    else
      if @attributes.has_key?(attribute)             &&
         !self.class.column_names.include?(attribute) &&
         !methods.include?(attribute)                 &&
         !self.class.safe_method_type([attribute])
      # db fetch only: select 'created_at AS age' ----> 'age' can be read
        @attributes[attribute]
      else
        super
      end
    end
  end

  # check inheritance chain through kpath
  def kpath_match?(kpath)
    vclass.kpath =~ /^#{kpath}/
  end

  # virtual class
  def vclass
    virtual_class || self.class
  end

  def klass
    @new_klass || @set_klass || vclass.to_s
  end

  def dyn_attribute_keys
    (version.dyn.keys + (virtual_class ? virtual_class.dyn_keys.to_s.split(',').map(&:strip) : [])).uniq.sort
  end

  def klass=(str)
    return if str == klass
    @new_klass = str
  end

  # include virtual classes to check inheritance chain
  def vkind_of?(klass)
    if self.class.ancestors.map{|k| k.to_s}.include?(klass)
      true
    elsif virt = VirtualClass.find(:first, :conditions=>["site_id = ? AND name = ?",current_site[:id], klass])
      kpath_match?(virt.kpath)
    end
  end

  # Update a node's attributes, transforming the attributes first from the visitor's context to Node context.
  def update_attributes_with_transformation(new_attributes)
    update_attributes(secure(Node) {Node.transform_attributes(new_attributes, self)})
  end

  # Replace [id], [v_title], etc in attributes values
  def replace_attributes_in_values(hash)
    hash.each do |k,v|
      v.gsub!(/\[([^\]]+)\]/) do
        attribute = $1
        real_attribute = attribute =~ /\Ad_/ ? attribute : attribute.gsub(/\A(|[\w_]+)id(s?)\Z/, '\1zip\2')
        Node.zafu_attribute(self, real_attribute)
      end
    end
  end


  # Parse text content and replace all relative urls ('../projects/art') by ids ('34')
  def parse_assets(text, helper, key)
    # helper is used in textdocuments
    ZazenParser.new(text,:helper=>helper).render(:translate_ids => :zip, :node => self)
  end

  # Parse text and replace ids '!30!' by their pseudo path '!(img/bird)!'
  def unparse_assets(text, helper, key)
    ZazenParser.new(text,:helper=>helper).render(:translate_ids => :relative_path, :node=>self)
  end

  # Return the list of ancestors (without self): [root, obj, obj]
  # ancestors to which the visitor has no access are removed from the list
  def ancestors(start=[])
    raise Zena::InvalidRecord, "Infinit loop in 'ancestors' (#{start.inspect} --> #{self[:id]})" if start.include?(self[:id])
    start += [self[:id]]
    if self[:id] == current_site[:root_id]
      []
    elsif self[:parent_id].nil?
      []
    else
      parent = @parent || Node.find(self[:parent_id])
      parent.visitor = visitor
      if parent.can_read?
        parent.ancestors(start) + [parent]
      else
        parent.ancestors(start)
      end
    end
  end


  # Return the same basepath as the parent. Is overwriten by 'Page' class.
  def basepath(rebuild=false, update= true)
    if !self[:basepath] || rebuild
      if self[:parent_id]
        parent = parent(false)
        path = parent ? parent.basepath(rebuild) : ''
      else
        path = ''
      end
      self.connection.execute "UPDATE #{self.class.table_name} SET basepath='#{path}' WHERE id='#{self[:id]}'" if path != self[:basepath] && update
      self[:basepath] = path
    end
    self[:basepath]
  end

  # Return the full path as an array if it is cached or build it when asked for.
  def fullpath(rebuild=false, update = true, loop_ids = [])
    return "" if loop_ids.include?(self.id)
    loop_ids << self.id
    if !self[:fullpath] || rebuild
      if parent = parent(false)
        path = parent.fullpath(rebuild,true,loop_ids).split('/') + [name.gsub("'",'')]
      else
        path = []
      end
      path = path.join('/')
      self.connection.execute "UPDATE #{self.class.table_name} SET fullpath='#{path}' WHERE id='#{self[:id]}'" if path != self[:fullpath] && update
      self[:fullpath] = path
    end
    self[:fullpath]
  end

  # Same as fullpath, but the path includes the root node.
  def rootpath
    current_site.name + (fullpath != "" ? "/#{fullpath}" : "")
  end

  alias path rootpath

  # Return an array with the node name and the last two parents' names.
  def short_path
    path = self.rootpath.split('/')
    if path.size > 2
      ['..'] + path[-2..-1]
    else
      path
    end
  end

  def pseudo_id(root_node, sym)
    case sym
    when :zip
      self.zip
    when :relative_path
      full = self.fullpath
      root = root_node ? root_node.fullpath : ''
      "(#{full.rel_path(root)})"
    end
  end

  # Return save path for an asset (element produced by text like a png file from LateX)
  def asset_path(asset_filename)
    # It would be nice to move this outside 'self[:id]' so that the same asset can
    # be used by many pages... But then, how do we expire unused assets ?
    "#{SITES_ROOT}#{site.data_path}/asset/#{self[:id]}/#{asset_filename}"
  end

  # Used by zafu to find the search score
  # def score
  #   self[:score]
  # end

  def all_relations
    @all_relations ||= self.vclass.all_relations(self)
  end

  # Find parent
  def parent(is_secure = true)
    # make sure the cache is in sync with 'parent_id' (used during validation)
    if self[:parent_id].nil?
      nil
    elsif is_secure
      # cache parent result (done through secure query)
      return @parent if @parent && @parent[:id] == self[:parent_id]
      @parent = secure(Node) { Node.find(self[:parent_id]) }
    else
      # not secured (inside an exclusive scope)
      return @parent_insecure if @parent_insecure && @parent_insecure[:id] == self[:parent_id]
      @parent_insecure = secure(Node, :secure => false) { Node.find(self[:parent_id]) }
    end
  end

  # Return self if the current node is a section else find section.
  def section
    self.kind_of?(Section) ? self : real_section
  end

  # Find real section
  def real_section(is_secure = true)
    return self if self[:parent_id].nil? # root
    # we cannot use Section to find because the root node behaves like a Section but is a Project.
    if is_secure
      secure(Node) { Node.find(self[:section_id]) }
    else
      secure(Node, :secure => false) { Node.find(self[:section_id]) }
    end
  end

  # Return self if the current node is a project else find project.
  def project
    self.kind_of?(Project) ? self : real_project
  end

  # Find real project (Project's project if node is a Project)
  def real_project(is_secure = true)
    return self if self[:parent_id].nil?
    if is_secure
      secure(Project) { Project.find(self[:project_id]) }
    else
      secure(Node, :secure => false) { Project.find(self[:project_id]) }
    end
  end

  # Create a child and let him inherit from rwp groups and section_id
  def new_child(opts={})
    klass = opts.delete(:class) || Page
    c = klass.new(opts)
    c.parent_id  = self[:id]
    c.instance_variable_set(:@parent, self)

    c.visitor    = visitor

    c.inherit = 1
    c.rgroup_id  = self.rgroup_id
    c.wgroup_id  = self.wgroup_id
    c.dgroup_id  = self.dgroup_id

    c.section_id = self.get_section_id
    c.project_id = self.get_project_id
    c
  end

  # ACCESSORS
  def author
    user.contact
  end

  # Find icon through a relation named 'icon' or use first image child
  def icon
    return nil if new_record?
    return @icon if defined? @icon
    query = Node.build_find(:first, ['icon group by id,l_id order by l_id desc, position asc, name asc', 'image'], :node_name => 'self')
    sql_str, uses_node_name = query.to_s, query.uses_node_name
    @icon = sql_str ? do_find(:first, eval(sql_str), :ignore_source => !uses_node_name) : nil
  end

  alias o_user user

  def user
    secure!(User) { o_user }
  end

  # Find all data entries linked to the current node
  def data
    list = DataEntry.find(:all, :conditions => "node_a_id = #{id} OR node_b_id = #{id} OR node_c_id = #{id} OR node_d_id = #{id}", :order => 'date ASC,created_at ASC')
    list == [] ? nil : list
  end

  if Node.connection.tables.include?('data_entries')
    # We need this guard during initial migration (Node loaded before data entries table is created).
    # FIXME: remove in [1.1] when we 'squash' all migrations

    DataEntry::NodeLinkSymbols.each do |sym|
      # Find data entries through a specific slot (node_a, node_b). "data_entries_a" finds all data entries link through 'node_a_id'.
      class_eval "def #{sym.to_s.gsub('node', 'data')}
        return nil if new_record?
        list = DataEntry.find(:all, :conditions=>\"#{sym}_id = '\#{self[:id]}'\")
        list == [] ? nil : list
      end"
    end
  end

  def ext
    (name && name != '' && name =~ /\./ ) ? name.split('.').last : ''
  end

  # set name: remove all accents and camelize
  def name=(str)
    return unless str && str != ""
    self[:name] = str.url_name
  end

  # Return current discussion id (used by query_builder)
  def get_discussion_id
    (discussion && !discussion.new_record?) ? discussion[:id] : '0'
  end

  # Return self[:id] if the node is a kind of Section. Return section_id otherwise.
  def get_section_id
    # root node is it's own section and project
    self[:parent_id].nil? ? self[:id] : self[:section_id]
  end

  # Return self[:id] if the node is a kind of Project. Return project_id otherwise.
  def get_project_id
    # root node is it's own section and project
    self[:parent_id].nil? ? self[:id] : self[:project_id]
  end

  # Id to zip mapping for parent_id. Used by zafu and forms.
  def parent_zip
    parent ? parent[:zip] : nil
  end

  # Id to zip mapping for section_id. Used by zafu and forms.
  def section_zip
    section[:zip]
  end

  # Id to zip mapping for project_id. Used by zafu and forms.
  def project_zip
    project[:zip]
  end

  # Id to zip mapping for user_id. Used by zafu and forms.
  def user_zip; self[:user_id]; end

  # transform to another class
  # def vclass=(new_class)
  #   if new_class.kind_of?(String)
  #     klass = Module.const_get(new_class)
  #   else
  #     klass = new_class
  #   end
  #   raise NameError if !klass.ancestors.include?(Node) || klass.version_class != self.class.content_class
  #
  #
  #
  # rescue NameError
  #   errors.add('klass', 'invalid')
  # end

  # transform an Node into another Object. This is a two step operation :
  # 1. create a new object with the attributes from the old one
  # 2. move old object out of the way (setting parent_id and section_id to -1)
  # 3. try to save new object
  # 4. delete old and set new object id to old
  # THIS IS DANGEROUS !! NEEDS TESTING
  # def change_to(klass)
  #   return nil if self[:id] == current_site[:root_id]
  #   # ==> Check for class specific information (file to remove, participations, tags, etc) ... should we leave these things and
  #   # not care ?
  #   # ==> When changing into something else : update version type and data !!!
  #   my_id = self[:id].to_i
  #   my_parent = self[:parent_id].to_i
  #   my_project = self[:section_id].to_i
  #   connection = self.class.connection
  #   # 1. create a new object with the attributes from the old one
  #   new_obj = secure!(klass) { klass.new(self.attributes) }
  #   # 2. move old object out of the way (setting parent_id and section_id to -1)
  #   self.class.connection.execute "UPDATE #{self.class.table_name} SET parent_id='0', section_id='0' WHERE id=#{my_id}"
  #   # 3. try to save new object
  #   if new_obj.save
  #     tmp_id = new_obj[:id]
  #     # 4. delete old and set new object id to old. Delete tmp Version.
  #     self.class.connection.execute "DELETE FROM #{self.class.table_name} WHERE id=#{my_id}"
  #     self.class.connection.execute "DELETE FROM #{Version.table_name} WHERE node_id=#{tmp_id}"
  #     self.class.connection.execute "UPDATE #{self.class.table_name} SET id='#{my_id}' WHERE id=#{tmp_id}"
  #     self.class.connection.execute "UPDATE #{self.class.table_name} SET section_id=id WHERE id=#{my_id}" if new_obj.kind_of?(Section)
  #     self.class.logger.info "[#{self[:id]}] #{self.class} --> #{klass}"
  #     if new_obj.kind_of?(Section)
  #       # update section_id for children
  #       sync_section(my_id)
  #     elsif self.kind_of?(Section)
  #       # update section_id for children
  #       sync_section(parent[:section_id])
  #     end
  #     secure ( klass ) { klass.find(my_id) }
  #   else
  #     # set object back
  #     self.class.connection.execute "UPDATE #{self.class.table_name} SET parent_id='#{my_parent}', section_id='#{my_project}' WHERE id=#{my_id}"
  #     self
  #   end
  # end

  # Find the discussion for the current context (v_status and v_lang). This automatically creates a new #Discussion if there is
  # no closed or open discussion for the current lang and Node#can_auto_create_discussion? is true
  def discussion
    return @discussion if defined?(@discussion)

    @discussion = Discussion.find(:first, :conditions=>[ "node_id = ? AND inside = ? AND lang = ?",
      self[:id], v_status != Zena::Status[:pub], v_lang ], :order=>'id DESC') ||
      if can_auto_create_discussion?
        Discussion.new(:node_id=>self[:id], :lang=>v_lang, :inside=>(v_status != Zena::Status[:pub]))
      else
        nil
      end
  end

  # Automatically create a discussion if any of the following conditions are met:
  # - there already exists an +outside+, +open+ discussion for another language
  # - the node is not published (creates an internal discussion)
  # - the user has drive access to the node
  def can_auto_create_discussion?
    can_drive? ||
    (v_status != Zena::Status[:pub]) ||
    Discussion.find(:first, :conditions=>[ "node_id = ? AND inside = ? AND open = ?",
                             self[:id], false, true ])
  end

  # FIXME: use nested_attributes_alias and try to use native Rails to create the comment
  # comment_attributes=, ...
  def m_text; ''; end
  def m_title; ''; end
  def m_author; ''; end

  def m_text=(str)
    @add_comment ||= {}
    @add_comment[:text] = str
  end

  def m_title=(str)
    @add_comment ||= {}
    @add_comment[:title] = str
  end

  def m_author=(str)
    @add_comment ||= {}
    @add_comment[:author] = str
  end

  # Comments for the current context. Returns nil when there is no discussion.
  def comments
    if discussion
      res = discussion.comments(:with_prop=>can_drive?)
      res == [] ? nil : res
    else
      nil
    end
  end

  # TODO: remove, replace by relation proxy: proxy.count...
  def comments_count
    if discussion
      discussion.comments_count(:with_prop=>can_drive?)
    else
      0
    end
  end

  # Return true if it is allowed to add comments to the node in the current context
  def can_comment?
    visitor.commentator? && discussion && discussion.open?
  end

  # TODO: test
  def sweep_cache
    return if current_site.being_created?
    # zafu 'erb' rendering cache expire
    # TODO: expire only 'dev' rendering if version is a redaction
    CachedPage.expire_with(self) if self.kind_of?(Template)

    # Clear element cache
    Cache.sweep(:visitor_id=>self[:user_id], :visitor_groups=>[rgroup_id, wgroup_id, dgroup_id], :kpath=>self.vclass.kpath)

    # Clear full result cache

    # we want to be sure to find the project and parent, even if the visitor does not have an
    # access to these elements.
    # FIXME: use self + modified relations instead of parent/project
    [self, self.real_project(false), self.real_section(false), self.parent(false)].compact.uniq.each do |obj|
      # destroy all pages in project, parent and section !
      CachedPage.expire_with(obj)
      # this destroys less cache but might miss things like 'changes in project' that are displayed on every page.
      # CachedPage.expire_with(self, [self[:project_id], self[:section_id], self[:parent_id]].compact.uniq)
    end

    # clear assets
    FileUtils::rmtree(asset_path(''))
  end

  # Include data entry verification in multiversion's empty? method.
  def empty?
    return true if new_record?
    super && 0 == self.class.count_by_sql("SELECT COUNT(*) FROM #{DataEntry.table_name} WHERE node_a_id = #{id} OR node_b_id = #{id} OR node_c_id = #{id} OR node_d_id = #{id}")
  end

  # create a 'tgz' archive with node content and children, returning temporary file path
  def archive
    n = 0
    while true
      folder_path = File.join(RAILS_ROOT, 'tmp', sprintf('%s.%d.%d', 'archive', $$, n))
      break unless File.exists?(folder_path)
    end

    begin
      FileUtils::mkpath(folder_path)
      export_to_folder(folder_path)
      tempf = Tempfile.new(name)
      `cd #{folder_path}; tar czf #{tempf.path} *`
    ensure
      FileUtils::rmtree(folder_path)
    end
    tempf
  end

  # export node content and children into a folder
  def export_to_folder(path)
    children = secure(Node) { Node.find(:all, :conditions=>['parent_id = ?', self[:id] ]) }

    if kind_of?(Document) && version.title == name && (kind_of?(TextDocument) || version.text.blank? || version.text == "!#{zip}!")
      # skip zml
      # TODO: this should better check that version content is really useless
    elsif version.title == name && version.text.blank? && klass == 'Page' && children
      # skip zml
    else
      File.open(File.join(path, name + '.zml'), 'wb') do |f|
        f.puts self.to_yaml
      end
    end

    if kind_of?(Document)
      data = kind_of?(TextDocument) ? StringIO.new(version.text) : version.content.file
      File.open(File.join(path, filename), 'wb') { |f| f.syswrite(data.read) }
    end

    if children
      content_folder = File.join(path,name)
      FileUtils::mkpath(content_folder)
      children.each do |child|
        child.export_to_folder(content_folder)
      end
    end
  end

  # export node as a hash
  def to_yaml
    hash = {}
    export_keys[:zazen].each do |k, v|
      hash[k] = unparse_assets(v, self, k)
    end

    export_keys[:dates].each do |k, v|
      hash[k] = visitor.tz.utc_to_local(v).strftime("%Y-%m-%d %H:%M:%S")
    end

    hash.merge!('class' => self.klass)
    hash.to_yaml
  end

  # List of attribute keys to export in a zml file.
  def export_keys
    {
      :zazen => version.export_keys[:zazen],
      :dates => version.export_keys[:dates],
    }
  end

  # List of attribute keys to transform (change references, etc).
  def parse_keys
    export_keys[:zazen].keys
  end

  # This is needed during 'unparse_assets' when the node is it's own helper
  def find_node_by_pseudo(string, base_node = nil)
    secure(Node) { Node.find_node_by_pseudo(string, base_node || self) }
  end

  protected

    # after node is saved, make sure it's children have the correct section set
    def spread_project_and_section
      if @spread_section_id || @spread_project_id
        # update children
        sync_section_and_project(@spread_section_id, @spread_project_id)
        remove_instance_variable :@spread_section_id if @spread_section_id
        remove_instance_variable :@spread_project_id if @spread_project_id
      end
    end

    #  node                       [change project and section]
    #    |
    #    +-- node                 [set project] [set section]
    #          |
    #          +-- section 4      [set project] [  keep     ]
    #          |     |
    #          |     +-- node     [set project] [  keep     ]
    #          |     |
    #          |     +-- project  [  keep     ] [  keep     ] => skip
    #          |
    #          +-- page           [set project] [set section]
    #          |
    #          +-- project        [  keep     ] [set section]
    #                |
    #                +-- node     [  keep     ] [set section]
    #                |
    #                +-- section  [  keep     ] [  keep     ] => skip
    def sync_section_and_project(section_id, project_id)

      # If this code is optimized, do not forget to sweep_cache for each modified child.
      all_children.each do |child|
        if child.kind_of?(Section)                     # [keep section] [set  project]
          next unless project_id                       # => skip
          # needed when doing 'sweep_cache'.
          visitor.visit(child)

          child[:project_id] = project_id              #                [set  project]
          child.save_with_validation(false)
          child.sync_section_and_project(    nil    , project_id)

        elsif child.kind_of?(Project)                  # [set  section] [keep project]
          next unless section_id                       # => skip
          # needed when doing 'sweep_cache'.
          visitor.visit(child)

          child[:section_id] = section_id              # [set  section]
          child.save_with_validation(false)
          child.sync_section_and_project(section_id,     nil   )
        else                                           # [set  section] [set  project]
          # needed when doing 'sweep_cache'.
          visitor.visit(child)

          child[:section_id] = section_id if section_id #[set  section]
          child[:project_id] = project_id if project_id #               [set  project]
          child.save_with_validation(false)
          child.sync_section_and_project(section_id, project_id)
        end
      end
    end

  private
    def node_before_validation
      self[:kpath] = self.vclass.kpath

      self.name ||= (version.title || '').url_name

      if ref_lang == version.lang &&
         ((full_drive? && version.status == Zena::Status[:pub]) ||
          (can_drive?  && vhash['r'][ref_lang].nil?))
        if name_changed? && !name.blank?
          version.title = self.name.gsub(/([A-Z])/) { " #{$1.downcase}" }
        elsif !version.title.blank?
          self.name = version.title.url_name
        end
      end

      unless name.blank?
        # update cached fullpath
        if new_record? || name_changed? || parent_id_changed?
          self[:fullpath] = self.fullpath(true,false)
        elsif !new_record? && custom_base_changed?
          self[:basepath] = self.basepath(true,false)
        end
        if !new_record? && fullpath_changed?
          # FIXME: update children's cached fullpaths
          @clear_children_fullpath = true
        end
      end

      # make sure section is the same as the parent
      if self[:parent_id].nil?
        # root node
        self[:section_id] = self[:id]
        self[:project_id] = self[:id]
      elsif parent
        self[:section_id] = ref.get_section_id
        self[:project_id] = ref.get_project_id
      else
        # bad parent will be caught later.
      end

      if !new_record? && self[:parent_id]
        # node updated and it is not the root node
        if !kind_of?(Section) && section_id_changed?
          @spread_section_id = self[:section_id]
        end
        if !kind_of?(Project) && project_id_changed?
          @spread_project_id = self[:project_id]
        end
      end

      # set position
      if klass != 'Node'
        # 'Node' does not have a position scope (need two first letters of kpath)
        if new_record?
          if self[:position].to_f == 0
            pos = Zena::Db.fetch_row("SELECT `position` FROM #{Node.table_name} WHERE parent_id = #{Node.connection.quote(self[:parent_id])} AND kpath like #{Node.connection.quote("#{self.class.kpath[0..1]}%")} ORDER BY position DESC LIMIT 1").to_f
            self[:position] = pos > 0 ? pos + 1.0 : 0.0
          end
        elsif parent_id_changed?
          # moved, update position
          pos = Zena::Db.fetch_row("SELECT `position` FROM #{Node.table_name} WHERE parent_id = #{Node.connection.quote(self[:parent_id])} AND kpath like #{Node.connection.quote("#{self.class.kpath[0..1]}%")} ORDER BY position DESC LIMIT 1").to_f
          self[:position] = pos > 0 ? pos + 1.0 : 0.0
        end
      end

    end

    # Make sure the node is complete before creating it (check parent and project references)
    def validate_node
      # when creating root node, self[:id] and :root_id are both nil, so it works.
      if parent_id_changed? && self[:id] == current_site[:root_id]
        errors.add("parent_id", "root should not have a parent") unless self[:parent_id].blank?
      end

      errors.add(:base, 'You do not have the rights to post comments.') if @add_comment && !can_comment?

      if @new_klass
        if !can_drive? || !self[:parent_id]
          errors.add('klass', 'You do not have the rights to do this.')
        else
          errors.add('klass', 'invalid') if !self.class.allowed_change_to_classes.include?(@new_klass)
        end
      end
    end

    # Called before destroy. An node must be empty to be destroyed
    def secure_on_destroy
      return false unless super
      # expire cache
      # TODO: test, use observer instead...
      CachedPage.expire_with(self)
      true
    end

    # Get unique zip in the current site's scope
    def node_before_create
      self[:zip] = Zena::Db.next_zip(self[:site_id])
    end

    # Create an 'outside' discussion if the virtual class has auto_create_discussion set
    def node_after_create
      if vclass.auto_create_discussion
        Discussion.create(:node_id=>self[:id], :lang=>v_lang, :inside => false)
      end
    end

    # Called after a node is 'unpublished'
    def after_unpublish
      if !self[:publish_from] && !@new_record_before_save
        # not published any more. 'unpublish' documents
        sync_documents(:unpublish)
      else
        true
      end
    end

    def after_redit
      return true if @new_record_before_save
      sync_documents(:redit)
    end

    # Called after a node is 'removed'
    def after_remove
      return true if @new_record_before_save
      sync_documents(:remove)
    end

    # Called after a node is 'proposed'
    def after_propose
      return true if @new_record_before_save
      sync_documents(:propose)
    end

    # Called after a node is 'refused'
    def after_refuse
      return true if @new_record_before_save
      sync_documents(:refuse)
    end

    # Called after a node is published
    def after_publish
      return true if @new_record_before_save
      sync_documents(:publish)
    end

    # Publish, refuse, propose the Documents of a redaction
    def sync_documents(action)
      allOK = true
      documents = secure_drive(Document) { Document.find(:all, :conditions=>"parent_id = #{self[:id]}") } || []
      case action
      when :propose
        documents.each do |doc|
          if doc.can_propose?
            allOK = doc.propose(Zena::Status[:prop_with]) && allOK
          end
        end
      when :unpublish
        # FIXME: use a 'before_unpublish' callback to make sure all sub-nodes can be unpublished...
        documents.each do |doc|
          unless doc.unpublish
            doc.errors.each do |k, v|
              errors.add('document', "#{k} #{v}")
            end
            allOK = false
          end
        end
      else
        documents.each do |doc|
          if doc.can_apply?(action)
            allOK = doc.apply(action) && allOK
          end
        end
      end
      allOK
    end

    # Whenever something changed (publication/proposition/redaction/link/...)
    def after_all
      sweep_cache
      if @add_comment
        # add comment
        @discussion ||= self.discussion
        @discussion.save if @discussion.new_record?
        @add_comment[:author_name] = nil unless visitor.is_anon? # only anonymous user should set 'author_name'
        @add_comment[:discussion_id] = @discussion[:id]
        @add_comment[:user_id]       = visitor[:id]

        @comment = secure!(Comment) { Comment.create(@add_comment) }

        remove_instance_variable(:@add_comment)
      end
      remove_instance_variable(:@discussion) if defined?(@discussion) # force reload

      true
    end

    def change_klass

      if @new_klass && !new_record?
        old_kpath = self.kpath

        klass = Node.get_class(@new_klass)
        if klass.kind_of?(VirtualClass)
          self[:vclass_id] = klass.kind_of?(VirtualClass) ? klass[:id] : nil
          self[:type]      = klass.real_class.to_s
        else
          self[:vclass_id] = klass.kind_of?(VirtualClass) ? klass[:id] : nil
          self[:type]      = klass.to_s
        end
        self[:kpath] = klass.kpath

        if old_kpath[/^NPS/] && !self[:kpath][/^NPS/]
          @spread_section_id = self[:section_id]
        elsif !old_kpath[/^NPS/] && self[:kpath][/^NPS/]
          @spread_section_id = self[:id]
        end

        if old_kpath[/^NPP/] && !self[:kpath][/^NPP/]
          @spread_project_id = self[:project_id]
        elsif !old_kpath[/^NPP/] && self[:kpath][/^NPP/]
          @spread_project_id = self[:id]
        end

        @set_klass = @new_klass
        remove_instance_variable(:@new_klass)
      end

      true
    end

    # Find all children, whatever visitor is here (used to check if the node can be destroyed or to update section_id)
    def all_children
      # FIXME: remove 'with_exclusive_scope' once scopes are clarified and removed from 'secure'
      Node.send(:with_exclusive_scope) do
        Node.find(:all, :conditions=>['parent_id = ?', self[:id] ])
      end
    end

    def clear_children_fullpath(i = self[:id])
      return true unless @clear_children_fullpath
      base_class.connection.execute "UPDATE nodes SET fullpath = NULL WHERE #{ref_field(false)}='#{i}'"
      ids = nil
      # FIXME: remove 'with_exclusive_scope' once scopes are clarified and removed from 'secure'
      base_class.send(:with_exclusive_scope) do
        ids = Zena::Db.fetch_ids("SELECT id FROM #{base_class.table_name} WHERE #{ref_field(true)} = '#{i.to_i}' AND inherit='1'")
      end

      ids.each { |i| clear_children_fullpath(i) }
      true
    end

    # Base class
    def base_class
      Node
    end

    # Reference class
    def ref_class
      Node
    end

    # return the id of the reference
    def ref_field(for_heirs=false)
      if !for_heirs && (self[:id] == current_site[:root_id])
        :id # root is it's own reference
      else
        :parent_id
      end
    end

end

Bricks::Patcher.apply_patches