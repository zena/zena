# encoding: utf-8
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
        |
        +--- Post (blog entry)


=== Properties

The Version class stores the node's properties (attributes). You need to declare the attributes either in the virtual class or as a Role attached to an existing class in order to use them.

=== Attributes

Each node uses the following basic attributes:

Base attributes:

zip:: unique id (incremented in each site's scope).
_id:: cached title (used to identify nodes in DB: not used in Zena)
site_id:: site to which this node belongs to.
parent_id:: parent node (every node except root is inserted in a unique place through this attribute).
user_id:: creator of the node.
ref_lang:: original node language.
created_at:: creation date.
updated_at:: modification date.
log_at:: announcement date.
event_at:: event date.
custom_base:: boolean value. When set to true, the node's url becomes it's fullpath. All it descendants will use this node's fullpath as their base url. See below for an example.
inherit:: inheritance mode (0=custom, 1=inherit, -1=private).

Attributes inherited from the parent:
section_id:: reference project (cannot be overwritten even if inheritance mode is custom).
rgroup_id:: id of the readers group.
wgroup_id:: id of the writers group.
dgroup_id:: id of the publishers group.
skin_id:: Skin to use when rendering the page ('theme').

Attributes used internally:
publish_from:: earliest publication date from all published versions.
kpath:: inheritance hierarchy. For example an Image has 'NPDI' (Node, Page, Document, Image), a Letter would have 'NNTL' (Node, Note, Task. Letter). This is used to optimize sql queries.
fullpath:: cached full path made of ancestors' zip (<gdparent zip>/<parent zip>/<self zip>).
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
  # Only store partial class name in 'type' field (Page instead of ::Page)
  self.store_full_sti_class = false

  extend Zena::Use::Upload::UploadedFile
  extend Zena::Use::Search::NodeClassMethods

  include Property

  # This must come before the first call to make_schema.
  include Zena::Use::Kpath::InstanceMethods

  def virtual_class
    @virtual_class ||= if self[:vclass_id]
      VirtualClass.find_by_id(self[:vclass_id])
    else
      VirtualClass.find_by_name(self.class.name)
    end
  end

  def virtual_class=(vclass)
    @virtual_class = vclass
    self[:vclass_id] = vclass.id
    self[:kpath] = vclass.kpath
  end

  # We want to use a Role as schema for properties defined in the real_class instead of Property::Schema.
  def self.make_schema
    ::Role.new(:name => name).tap do |role|
      role.kpath = self.kpath
      # Enable property method definitions.
      role.klass      = self
      # Used for property inheritance.
      role.real_class = self
    end
  end

  alias schema virtual_class

  # We use the virtual_class as proxy for method type resolution.
  # def safe_eval(code)
  #   eval RubyLess.translate(schema, code)
  # end

  def safe_method_type(signature, receiver = nil)
    schema.safe_method_type(signature, receiver)
  end

  # Should be the same serialization as in Version and Site
  include Property::Serialization::JSON

  store_properties_in :version

  property do |p|
    # Multilingual string index on 'title'
    p.string  'title', :index => :ml_string

    p.string  'text'
    p.string  'summary'
  end

  # This is used to enable multilingual indexes
  include Zena::Use::MLIndex::ModelMethods

  # Must come after Property
  include Zena::Use::FieldIndex::ModelMethods

  include RubyLess

  # This is used to load roles in an instance or on a class during compilation. Module
  # inclusion has to come *after* RubyLess because we overwrite safe_method_type.
  include Zena::Acts::Enrollable::ModelMethods

  #attr_accessible    :version_content
  has_many           :discussions, :dependent => :destroy
  has_many           :links
  has_and_belongs_to_many :cached_pages
  belongs_to         :site
  belongs_to         :skin
  before_validation  :set_defaults
  before_validation  :node_before_validation
  validate           :validate_node
  before_create      :node_before_create
  before_save        :change_klass
  after_save         :spread_project_and_section
  after_create       :node_after_create
  attr_protected     :zip, :id, :section_id, :project_id, :publish_from, :created_at, :updated_at
  attr_protected     :site_id

  # Until we find another way to write friend_ids, we need NestedAttributesAlias in Relations
  # A possible solution could be to use the other syntax exclusively ('rel' => {'friend' => [4,5,6]})
  include Zena::Use::NestedAttributesAlias::ModelMethods

  # Dynamic resolution of the author class from the user prototype
  def self.author_proc
    Proc.new do |h, r, s|
      res = {:method => 'author', :nil => true}
      if prototype = visitor.prototype
        res[:class] = prototype.vclass
      else
        res[:class] = VirtualClass['Node']
      end
      res
    end
  end

  safe_property  :title, :text, :summary

  safe_attribute :created_at, :updated_at, :event_at, :log_at, :publish_from, :basepath, :inherit, :position


  # safe_node_context defined in Enrollable
  safe_node_context  :parent => 'Node', :project => 'Project', :section => 'Section',
                     :real_project => 'Project', :real_section => 'Section'

  safe_context       :custom_a => Number, :custom_b => Number, #, :score => Number
                     :comments => ['Comment'],
                     # Code language for syntax highlighting
                     :content_lang => String,
                     :data   => {:class => ['DataEntry'], :zafu => {:data_root => 'node_a'}},
                     :data_a => {:class => ['DataEntry'], :zafu => {:data_root => 'node_a'}},
                     :data_b => {:class => ['DataEntry'], :zafu => {:data_root => 'node_b'}},
                     :data_c => {:class => ['DataEntry'], :zafu => {:data_root => 'node_c'}},
                     :data_d => {:class => ['DataEntry'], :zafu => {:data_root => 'node_d'}},
                     :traductions => ['Version'], :discussion  => 'Discussion',
                     :project => 'Node'

  # we use safe_method because the columns can be null, but the values are never null
  safe_method        :kpath => String, :user_zip => Number,
                     :parent_zip => Number, :project_zip => Number, :section_zip => Number,
                     :ref_lang => String,
                     :position => Number, :rgroup_id => Number,
                     :wgroup_id => Number, :dgroup_id => Number, :custom_base => Boolean,
                     :klass => String,
                     :m_text => String, :m_title => String, :m_author => String,
                     :id => {:class => Number, :method => 'zip'},
                     :skin => 'Skin', :ref_lang => String,
                     :visitor => 'User', [:ancestor?, Node] => Boolean,
                     :comments_count => Number,
                     :v => {:class => 'Version', :method => 'version'},
                     :version => 'Version', :v_status => Number, :v_lang => String,
                     :v_publish_from => Time, :v_backup => Boolean,
                     :zip => Number, :parent_id => {:class => Number, :nil => true, :method => 'parent_zip'},
                     :user => 'User',
                     :author => author_proc,
                     :vclass => {:class => 'VirtualClass', :method => 'virtual_class'}

  # This is needed so that we can use secure_scope and secure in search.
  extend  Zena::Acts::Secure
  extend  Zena::Acts::SecureNode
  acts_as_secure_node

  # These *must* be included in this order
  include Versions::Multi
  has_multiple :versions, :inverse => 'node'

  include Zena::Use::Workflow
  include Zena::Use::Ancestry::ModelMethods

  # to_xml
  include Zena::Acts::Serializable::ModelMethods

  # compute vhash (must come before Fulltext)
  include Zena::Use::VersionHash::ModelMethods

  # computed properties (vclass prop_eval, must come after MLIndex)
  include Zena::Use::PropEval::ModelMethods

  # fulltext indices (must come after PropEval)
  include Zena::Use::Fulltext::ModelMethods

  # List of version attributes that should be accessed as proxies 'v_lang', 'v_status', etc
  VERSION_ATTRIBUTES = %w{status lang publish_from backup}

  # The following methods are used in forms and affect the version.
  VERSION_ATTRIBUTES.each do |attribute|
    eval %Q{
      def v_#{attribute}
        version.#{attribute}
      end

      def v_#{attribute}=(value)
        version.#{attribute} = value
      end
    }
  end

  def v_number
    version.number
  end

  # This is an adaptation of Versions::Multi code to use our special v_ shortcut
  # to access version attributes.
  def merge_multi_errors(key, object)
    if key == 'version'
      super('v', object)
    else
      super
    end
  end

  include Zena::Use::Relations::ModelMethods

  # model based indices (must come after Relations)
  include Zena::Use::ScopeIndex::ModelMethods

  include Zena::Use::QueryNode::ModelMethods

  @@native_node_classes = {'N' => self}
  @@native_node_classes_by_name = {'Node' => self}
  @@unhandled_children  = []

  class << self
    def new(hash={}, vclass = nil)
      node = super()
      # set virtual_class (acts as schema) before setting attributes
      node.virtual_class = vclass || VirtualClass[self.name]
      node.attributes = hash
      node
    end

    # Compatibility with VirtualClass
    alias new_instance new

    # Compatibility with VirtualClass
    alias create_instance create

    def inherited(child)
      super
      unless child.name.blank?
        # Do not register anonymous classes created during Zafu compilation
        @@unhandled_children << child
      end
    end

    def find_by_parent_title_and_kpath(parent_id, title, kpath = nil, opts = {})
      if cond = opts[:conditions]
        cond[0] = Array(cond[0])
      else
        cond = opts[:conditions] = [[]]
      end

      if kpath
        cond[0] << "kpath like ?"
        cond << "#{kpath}%"
      end
      cond[0] << "site_id = ? AND parent_id = ?"
      cond << current_site.id << parent_id

      find_by_title(title, opts)
    end

    # Find node by the indexed title.
    def find_by_title(title, opts = {})
      if cond = opts[:conditions]
        cond[0] = Array(cond[0])
      else
        cond = opts[:conditions] = [[]]
      end

      if opts.delete(:like)
        cond[0] << "id1.value LIKE ?"
      else
        cond[0] << "id1.value = ?"
      end
      cond << title

      cond[0] = cond[0].join(' AND ')

      opts[:joins] = Node.title_join
      opts[:select] = 'nodes.*'

      Node.find(:first, opts)
    end

    # Return the list of (kpath,subclasses) for the current class.
    def native_classes
      load_unhandled_children
      @@native_node_classes
    end

    # Return the list of (name,class) for the current class.
    def native_classes_by_name
      load_unhandled_children
      @@native_node_classes_by_name
    end

    def load_unhandled_children
      # this is to make sure subclasses are loaded before the first call
      # TODO: find a better way to make sure they are all loaded
      [Note,Page,Project,Section,Document,Image,TextDocument,Skin,Template]
      while child = @@unhandled_children.pop
        @@native_node_classes[child.kpath] = child
        @@native_node_classes_by_name[child.name] = child
      end
    end

    # check inheritance chain through kpath
    def kpath_match?(kpath)
      self.kpath =~ /^#{kpath}/
    end

    # Class list to which this class can change to
    def change_to_classes_for_form
      classes_for_form(:class => 'Node', :without => 'Document')
    end

    # List of classes that a node can change to.
    def allowed_change_to_classes
      change_to_classes_for_form.map {|k,v| v}
    end

    # TODO: remove and use VirtualClass[...].classes_for_form directly
    def classes_for_form(opts={})
      VirtualClass[self.name].classes_for_form(opts)
    end

    # FIXME: how to make sure all sub-classes of Node are loaded before this is called ?
    # TODO: move into helper
    def kpaths_for_form(opts={})
      VirtualClass.all_classes(opts).map do |vclass|
        # white spaces are insecable spaces (not ' ')
        a, b = vclass.kpath, vclass.name
        [a[1..-1].gsub(/./,'  ') + b, a]
      end
    end

    # Return class or virtual class from name.
    # FIXME: remove once everything can use VirtualClass[name]
    def get_class(rel, opts={})
      # mushroom_types ==> MushroomType
      class_name = rel =~ /\A[a-z]/ ? rel.singularize.camelize : rel
      vclass = VirtualClass.find_by_name(class_name)
      if opts[:create] && vclass.id
        # TODO: how do we deal with real class ? (Currently = pass).
        visitor.group_ids.include?(vclass.create_group_id) ? vclass : nil
      else
        vclass
      end
    end

    # Find a role by name.
    def get_role(rel)
      # mushroom_types ==> MushroomType
      role_name = rel =~ /\A[a-z]/ ? rel.singularize.camelize : rel
      Role.first(:conditions => ['name = ? AND site_id = ?', role_name, current_site.id])
    end

    # Find a node's attribute based on a pseudo (id or path). Used by zazen to create a link for ""::art or "":(people/ant) for example.
    def translate_pseudo_id(id, sym = :id, base_node = nil)
      if id.to_s =~ /\A(-?)(\d+)\Z/
        # zip
        # FIXME: this is not secure
        res = Zena::Db.fetch_attribute("SELECT #{sym} FROM nodes WHERE site_id = #{current_site[:id]} AND zip = '#{$2}'")
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
        Node.search_records($1.gsub('-',' '), :offset => offset, :limit => 1).first
      elsif path = str[/\A\(([^\)]+)\)\Z/,1]
        if path[0..0] == '/'
          path = path[1..-1].split('/').map {|p| String.from_filename(p) }
          find_by_path(path)
        elsif base_node
          # transform ../../foo and 45/32/61/72 ==> 'foo' and 45/32
          path = path.split('/')
          root = base_node.fullpath.split('/')
          while path[0] == '..'
            root.pop
            path.shift
          end

          path = path.map {|p| String.from_filename(p) }

          if base_node.zip == root.last.to_i
            find_by_path(path, base_node.id)
          elsif root.last
            if base = find_by_zip(root.last)
              find_by_path(path, base.id)
            else
              nil
            end
          else
            find_by_path(path)
          end
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

      v_lang = attributes['v_lang']
      if !current_site.lang_list.include?(v_lang)
        attributes['v_lang'] = current_site.lang_list.first
      end

      if zip = attributes.delete('parent_zip')
        if id = secure(Node) { Node.translate_pseudo_id(zip, :id, self) }
          attributes['parent_id'] = id
        else
          node = Node.new
          node.errors.add('parent_id', 'could not be found')
          return node
        end
      end

      unless attributes['title'] && attributes['parent_id']
        node = Node.new
        node.errors.add('title', "can't be blank")     if attributes['title'].blank?
        node.errors.add('parent_id', "can't be blank") if attributes['parent_id'].blank?
        return node
      end

      # FIXME: remove 'with_exclusive_scope' once scopes are clarified and removed from 'secure'
      node = Node.send(:with_exclusive_scope) do
        find_by_parent_title_and_kpath(attributes['parent_id'], attributes['title'], nil)
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
        node = create_node(attributes, false)
        node[:create_or_update] = 'new'
      end

      node
    end

    # TODO: cleanup and rename with something indicating the attrs cleanup that this method does.
    def new_node(new_attributes, transform = true)
      attributes = transform ? transform_attributes(new_attributes) : new_attributes

      klass_name = attributes.delete('class') || attributes.delete('klass') || 'Page'
      if klass_name.kind_of?(VirtualClass) || klass_name.kind_of?(Class)
        klass = klass_name
      else
        unless klass = get_class(klass_name, :create => true)
          node = Node.new
          node.instance_eval { @attributes.merge!(attributes) }
          node.errors.add('klass', 'invalid')
          # This is to show the klass in the form seizure
          node.instance_variable_set(:@klass, klass_name.to_s)
          def node.klass; @klass; end
          return node
        end
      end

      if klass.kind_of?(VirtualClass)
        node = secure(klass.real_class) { klass.new_instance(attributes) }
      else
        node = secure(klass) { klass.new_instance(attributes) }
      end
      node
    end

    # TODO: cleanup and rename with something indicating the attrs cleanup that this method does.
    def create_node(new_attributes, transform = true)
      node = new_node(new_attributes, transform)
      if node.errors.empty?
        node.save
      end
      node
    end

    # Create new nodes from the data in a folder or archive.
    def create_nodes_from_folder(opts)
      # TODO: all this needs refactoring (and moved into a module).
      # It's probably the messiest part of Zena.
      return [] unless (opts[:folder] || opts[:archive]) && (opts[:parent] || opts[:parent_id])
      scope = self.scoped_methods[0] || {}
      parent_id = opts[:parent_id] || opts[:parent][:id]
      folder    = opts[:folder]
      defaults  = (opts[:defaults] || {}).stringify_keys
      klass     = opts[:class] || opts[:klass] || "Page"
      res       = {}

      unless folder
        # Create from archive
        res = nil
        extract_archive(opts[:archive]) do |folder|
          res = create_nodes_from_folder(:folder => folder, :parent_id => parent_id, :defaults => defaults, :klass => klass)
        end

        return res
      end

      entries = Dir.entries(folder).reject { |f| f =~ /^([\._~])/ }.map do |filename|
        String.from_filename(filename)
      end.sort

      index  = 0

      while entries[index]
        type = current_obj = sub_folder = document_path = nil
        versions = []
        filename = entries[index]

        path     = File.join(folder, filename)

        if File.stat(path).directory?
          type       = :folder
          title      = filename
          sub_folder = path
          attrs      = defaults.dup
          attrs['v_lang'] ||= visitor.lang
        elsif filename =~ /^(.+?)(\.\w\w|)(\.\d+|)\.zml$/  # bird.jpg.en.zml
          # node content in yaml
          type      = :node
          title     = "#{$1}#{$4}"
          lang      = $2.blank? ? nil : $2[1..-1]

          # no need for base_node (this is done after all with parse_assets in the controller)
          attrs  = defaults.merge(get_attributes_from_yaml(path))
          attrs['title'] = title
          attrs['v_lang']    = lang || attrs['v_lang'] || visitor.lang
          versions << attrs
        elsif filename =~ /^((.+?)\.(.+?))(\.\w\w|)(\.\d+|)$/ # bird.jpg.en
          type      = :document
          title     = $1
          attrs     = defaults.dup
          lang      = $4.blank? ? nil : $4[1..-1]
          attrs['v_lang'] = lang || attrs['v_lang'] || visitor.lang
          attrs['ext']  = $3
          document_path = path
        end

        index += 1
        while entries[index] =~ /^#{title}(\.\w\w|)(\.\d+|)\.zml$/ # bird.jpg.en.zml
          lang   = $1.blank? ? visitor.lang : $1[1..-1]
          path   = File.join(folder,entries[index])

          # we have a zml file. Create a version with this file
          # no need for base_node (this is done after all with parse_assets in the controller)
          attrs = defaults.merge(get_attributes_from_yaml(path))
          attrs['title']  ||= title
          attrs['v_lang'] ||= lang
          versions << attrs

          index += 1
        end

        if versions.empty?
          if type == :folder
            # minimal node for a folder
            attrs['title']    = title
            attrs['v_lang'] ||= lang
            attrs['class']    = klass
            versions << attrs
          elsif type == :document
            # minimal node for a document
            attrs['title']    = title
            attrs['v_lang'] ||= lang
            versions << attrs
          end
        end

        new_object = false
        versions.each do |attrs|
          # FIXME: same lang: remove before update current_obj.remove if current_obj.v_lang == attrs['v_lang'] && current_obj.v_status != Zena::Status[:red]
          # FIXME: current_obj.publish if attrs['v_status'].to_i == Zena::Status[:pub]
          if type == :document
            attrs['title' ] = attrs['title'].split('.')[0..-2].join('.')
            if document_path
              attrs['ext'] ||= document_path.split('.').last
              # file
              insert_zafu_headings = false
              if opts[:parent_class] == 'Skin' && ['html','xhtml'].include?(attrs['ext']) && attrs['title'] == 'index'
                attrs['ext']   = 'zafu'
                attrs['title'] = 'Node'
                insert_zafu_headings = true
              end

              ctype = Zena::EXT_TO_TYPE[attrs['ext']]
              ctype = ctype ? ctype[0] : "application/octet-stream"
              attrs['content_type'] = ctype


              File.open(document_path) do |f|
                file = uploaded_file(f, filename, ctype)
                (class << file; self; end;).class_eval do
                  alias o_read read
                  define_method(:read) do
                    if insert_zafu_headings
                      o_read.sub(%r{</head>},"  <r:stylesheets/>\n  <r:javascripts/>\n  <r:uses_datebox/>\n</head>")
                    else
                      o_read
                    end
                  end
                end
                current_obj = create_or_update_node(attrs.merge(:file => file, :klass => 'Document', :_parent_id => parent_id))
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

    def extract_archive(archive)
      begin
        n = 0
        # TODO: we could move the tmp folder inside sites/{current_site}/tmp
        folder = File.join(RAILS_ROOT, 'tmp', sprintf('%s.%d.%d', 'import', $$, n))
      end while File.exists?(folder)

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
        # FIXME: SECURITY is there a security risk here ?
        # FIXME: not compatible with Windows.
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
        yield folder
      ensure
        FileUtils::rmtree(folder)
      end
    end

    def find_by_zip(zip)
      node = find(:first, :conditions=>"zip = #{zip.to_i}")
      raise ActiveRecord::RecordNotFound unless node
      node
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
    def transform_attributes(new_attributes, base_node = nil, change_timezone = true, is_link = false)
      res = {}
      res['parent_id'] = new_attributes[:_parent_id] if new_attributes[:_parent_id] # real id set inside zena.

      attributes = new_attributes.stringify_keys

      if attributes['copy'] || attributes['copy_id']
        copy_node = attributes.delete('copy')
        copy_node ||= Node.find_by_zip(attributes.delete('copy_id'))
        attributes = copy_node.replace_attributes_in_values(attributes)
      end

      if !res['parent_id'] && p = attributes['parent_id']
        res['parent_zip'] = p
      end

      attributes.each do |key, value|
        next if ['parent_id', 'parent_zip', '_parent_id'].include?(key)

        if %w{rgroup_id wgroup_id dgroup_id}.include?(key)
          res[key] = Group.translate_pseudo_id(value, :id) || value
        elsif %w{rgroup wgroup dgroup}.include?(key)
          res["#{key}_id"] = Group.translate_pseudo_id(value, :id) || value
        elsif %w{user_id}.include?(key)
          res[key] = User.translate_pseudo_id(value, :id) || value
        elsif %w{link_id}.include?(key)
          # Link id, not translated
          res[key] = value
        elsif %w{id create_at updated_at}.include?(key)
          # ignore (can be present in xml)
        elsif %w{log_at event_at v_publish_from}.include?(key) || (is_link && %w{date}.include?(key))
          # FIXME: !!! We need to fix timezone parsing in dates depending on the Schema used. This means
          # that we probably need to do this at the property level (during write).
          if value.kind_of?(Time)
            res[key] = value
          elsif value
            # parse date
            if key == 'date'
              # TODO: this is a temporary hack because date in links do not support timezones/formats properly
              res[key] = value.to_utc("%Y-%m-%d %H:%M:%S")
            else
              res[key] = value.to_utc(_('datetime'), change_timezone ? visitor.tz : nil)
            end
          end
        elsif key =~ /^(\w+)_id$/
          res["#{$1}_zip"] = value
        elsif key =~ /^(\w+)_ids$/
          res["#{$1}_zips"] = value.kind_of?(Array) ? value : value.split(',')
        elsif key == 'file'
          unless value.blank?
            res[key] = value
          end
        elsif value.kind_of?(Hash)
          res[key] = transform_attributes(value, base_node, change_timezone, %w{link rel rel_attributes}.include?(key) || is_link)
        else
          # translate zazen
          if value.kind_of?(String)
            # FIXME: ignore if 'text' of a TextDocument...
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

    def safe_method_type(signature, receiver = nil)
      if signature.size > 1
        RubyLess::SafeClass.safe_method_type_for(self, signature)
      else
        method = signature.first

        if type = super
          type
        elsif method == 'cached_role_ids'
          # TODO: how to avoid everything ending in '_id' being caught as relations ?
          nil
        elsif method =~ /^(.+)_((id|zip|status|comment)(s?))\Z/ && !instance_methods.include?(method)
          key = $3 == 'id' ? "zip#{$4}" : $2
          {:method => "rel[#{$1.inspect}].try(:other_#{key})", :nil => true, :class => ($4.blank? ? Number : [Number])}
        else
          nil
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

    # Seeing all the columns of the Node class on every inspect does not help at all.
    def inspect
      to_s
    end

    def auto_create_discussion
      false
    end
  end

  # Remove loaded version and properties on reload.
  def reload
    @version    = nil
    @properties = nil
    super
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

  # check inheritance chain through kpath
  def kpath_match?(kpath)
    vclass.kpath =~ /^#{kpath}/
  end

  # virtual class
  # FIXME: alias vclass to virtual_class
  # alias vclass virtual_class
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
  def update_attributes_with_transformation(new_attributes, change_timezone = true)
    update_attributes(secure(Node) {Node.transform_attributes(new_attributes, self, change_timezone)})
  end

  # Replace [id], [title], etc in attributes values
  def replace_attributes_in_values(hash)
    hash.each do |k,v|
      hash[k] = safe_eval_string(v)
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

  # Return save path for an asset (element produced by text like a png file from LateX)
  def asset_path(asset_filename)
    # It would be nice to move this outside 'self[:id]' so that the same asset can
    # be used by many pages... But then, how do we expire unused assets ?
    "#{SITES_ROOT}#{site.data_path}/asset/#{self[:id]}/#{asset_filename}"
  end

  # Return the code language used for syntax highlighting.
  def content_lang
    ctype = prop['content_type']
    if ctype =~ /^text\/(.*)/
      case $1
      when 'x-ruby-script'
        'ruby'
      when 'html', 'zafu'
        'zafu'
      else
        $1
      end
    else
      nil
    end
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

  alias o_skin skin
  def skin
    @skin ||= secure(Skin) { o_skin }
  end

  # Create a child and let him inherit from rwp groups and section_id
  def new_child(opts={})
    c = Node.new_node(opts)
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
    user.node
  end

  alias o_user user

  # TODO: why do we need secure here ?
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
    @parent_zip || parent.try(:zip)
  end

  # When setting parent trough controllers, we receive parent_zip=.
  def parent_zip=(zip)
    @parent_zip = zip
  end

  # When setting skin trough controllers, we receive skin_zip=.
  def skin_zip=(zip)
    @skin_zip = zip.to_i
  end

  def skin_zip
    @skin_zip || skin.try(:zip)
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
      n += 1
      break unless File.exists?(folder_path)
    end

    begin
      FileUtils::mkpath(folder_path)
      export_to_folder(folder_path)
      tempf = Tempfile.new(title.to_filename)
      `cd #{folder_path.inspect}; tar czf #{tempf.path.inspect} *`
    ensure
      FileUtils::rmtree(folder_path)
    end
    tempf
  end

  # export node content and children into a folder
  def export_to_folder(path)
    children = secure(Node) { Node.find(:all, :conditions=>['parent_id = ?', self[:id] ]) }

    if kind_of?(Document) && (kind_of?(TextDocument) || text.blank? || text == "!#{zip}!")
      # skip zml
      # TODO: this should better check that version content is really useless
    elsif text.blank? && klass == 'Page' && children
      # skip zml
    else
      File.open(File.join(path, title.to_filename + '.zml'), 'wb') do |f|
        f.puts self.to_yaml
      end
    end

    if kind_of?(Document)
      data = kind_of?(TextDocument) ? StringIO.new(text) : file
      File.open(File.join(path, filename), 'wb') { |f| f.syswrite(data.read) }
    end

    if children
      content_folder = File.join(path, title.to_filename)
      if !FileUtils::mkpath(content_folder)
        puts "Problem..."
      end
      children.each do |child|
        child.export_to_folder(content_folder)
      end
    end
  end

  # FIXME: remove all this because we now have Zena::Acts::Serializable

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
      :zazen => Hash[*prop.select { |k, v| v.kind_of?(String) }.flatten],
      :dates => Hash[*prop.select { |k, v| v.kind_of?(Time) }.flatten],
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

  safe_method [:send, String] => {:class => String, :nil => true, :method => 'safe_send'}

  # Safe dynamic method dispatching when the method is not known during compile time. Currently this
  # only works for methods without arguments.
  def safe_send(method)
    return nil unless type = virtual_class.safe_method_type([method])
    res = eval(type[:method])
    res ? res.to_s : nil
  end

  protected

    # after node is saved, make sure it's children have the correct section set
    # FIXME: move this into Ancestry
    def spread_project_and_section
      # clear parent_zip
      @parent_zip = nil

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
    def set_defaults
      self[:custom_base] = false unless kind_of?(Page)
      true
    end

    def node_before_validation
      if @parent_zip
        if id = secure(Node) { Node.translate_pseudo_id(@parent_zip, :id, new_record? ? nil : self) }
          self.parent_id = id
        else
          @parent_zip_error = _('could not be found')
        end
      end

      if @skin_zip
        if node = secure(Node) { Node.find_by_zip(@skin_zip) }
          if !node.kind_of?(Skin)
            @skin_zip_error = _('type mismatch (%{type} is not a Skin)') % {:type => node.klass}
          else
            self.skin_id = node.id
          end
        else
          @skin_zip_error = _('could not be found')
        end
      end


      self[:kpath] = self.vclass.kpath

      # make sure section is the same as the parent
      if self[:parent_id].nil?
        # root node
        self[:section_id] = self[:id]
        self[:project_id] = self[:id]
      elsif ref = parent
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
            pos = Zena::Db.fetch_attribute("SELECT position FROM #{Node.table_name} WHERE parent_id = #{Node.connection.quote(self[:parent_id])} AND kpath like #{Node.connection.quote("#{self.class.kpath[0..1]}%")} ORDER BY position DESC LIMIT 1").to_f
            self[:position] = pos > 0 ? pos + 1.0 : 0.0
          end
        elsif parent_id_changed?
          # moved, update position
          pos = Zena::Db.fetch_attribute("SELECT position FROM #{Node.table_name} WHERE parent_id = #{Node.connection.quote(self[:parent_id])} AND kpath like #{Node.connection.quote("#{self.class.kpath[0..1]}%")} ORDER BY position DESC LIMIT 1").to_f
          self[:position] = pos > 0 ? pos + 1.0 : 0.0
        end
      end

    end

    # Make sure the node is complete before creating it (check parent and project references)
    def validate_node
      errors.add(:title, "can't be blank") if title.blank?

      if @parent_zip_error
        errors.add('parent_id', @parent_zip_error)
        @parent_zip_error = nil
      end

      if @skin_zip_error
        errors.add('skin_id', @skin_zip_error)
        @skin_zip_error = nil
      end

      # when creating root node, self[:id] and :root_id are both nil, so it works.
      if parent_id_changed? && self[:id] == current_site[:root_id]
        errors.add("parent_id", "root should not have a parent") unless self[:parent_id].blank?
      end

      errors.add(:base, 'You do not have the rights to post comments.') if @add_comment && !can_comment?

      if @new_klass
        if !can_drive? || !self[:parent_id]
          errors.add('klass', 'You do not have the rights to change class.')
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

    # This method is run whenever 'apply' is called.
    def after_all
      return unless super
      sweep_cache
      if @add_comment
        # add comment
        @discussion ||= self.discussion
        @discussion.save if @discussion.new_record?

        @comment = Comment.new(@add_comment)
        @comment.discussion_id = @discussion.id
        @comment.save

        remove_instance_variable(:@add_comment)
      end
      remove_instance_variable(:@discussion) if defined?(@discussion) # force reload

      true
    end

    def change_klass
      if @new_klass && !new_record?
        old_kpath = self.kpath
# FIXME ! (new virtual_class as schema...)
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

    def get_unique_title_in_scope(kpath)
      if prop.title_changed? || parent_id_changed? || kpath_changed?
        Node.send(:with_exclusive_scope) do
          if !new_record?
            cond = ['nodes.id != ?', id]
          else
            cond = nil
          end

          if taken_name = Node.find_by_parent_title_and_kpath(parent_id, title, kpath, :order => "LENGTH(id1.value) DESC", :select => 'id1.value', :conditions => cond)
            if taken_name =~ /^#{title}-(\d)/
              self.title = "#{title}-#{$1.to_i + 1}"
            else
              self.title = "#{title}-1"
            end
          end
        end
      end
    end
end

Bricks.apply_patches

# This is an ugly fix related to the circular dependency between Node and Version
class Version

  def node_with_secure
    @node ||= begin
      if n = secure(Node) { node_without_secure }
        n.version = self
      end
      n
    end
  end
  alias_method_chain :node, :secure
end
