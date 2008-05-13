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
pgroup_id                   title                 width
wgroup_id                   text                  height
user_id                     summary               content_type
...                         ...                   ...

=== Acessing version and content data

To ease the work to set/retrieve the data from the version and or content, we use some special notation. This notation abstracts this Node/Version/Content structure so you can use a version's attribute as if it was in the node directly.

Any attribute starting with +v_+ is sent to the node's version. For example, this is the recommended way to get the node's title :

 @node.v_title   # in a form: <%= text_field 'node', 'v_title' %>

Any method starting with +c_+ is sent directly to the node's content. For example, this is the recommended way to get an image's width :

 @node.c_width   # in a form: <%= text_field 'node', 'c_width' %>
 
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
pgroup_id:: id of the publishers group.
skin:: name of theSkin to use when rendering the pate ('theme').

Attributes used internally:
publish_from:: earliest publication date from all published versions.
max_status:: maximal status from all versions (see Version)
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
  
  zafu_readable      :name, :created_at, :updated_at, :event_at, :log_at, :kpath, :user_zip, :parent_zip, :project_zip,
                     :section_zip, :skin, :ref_lang, :fullpath, :rootpath, :position, :publish_from, :max_status, :rgroup_id, 
                     :wgroup_id, :pgroup_id, :basepath, :custom_base, :klass, :zip, :score, :comments_count, :position
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
                     
  has_many           :discussions, :dependent => :destroy
  has_and_belongs_to_many :cached_pages
  belongs_to         :virtual_class, :foreign_key => 'vclass_id'
  belongs_to         :site
  validate           :validate_node
  before_create      :node_before_create
  after_save         :spread_project_and_section
  before_destroy     :node_on_destroy
  attr_protected     :site_id, :zip, :id, :section_id, :project_id, :publish_from, :max_status
  attr_protected     :c_version_id, :c_node_id # TODO: test
  acts_as_secure_node
  acts_as_multiversioned
  use_node_query
  has_relations
  before_validation  :node_before_validation  # run our 'before_validation' after 'secure'
  
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

    def translate_pseudo_id(id,sym=:id)
      str = id.to_s
      if str =~ /\A\d+\Z/
        # zip
        res = Node.connection.execute( "SELECT #{sym} FROM nodes WHERE site_id = #{current_site[:id]} AND zip = '#{str}'" ).fetch_row
        res ? res[0].to_i : nil
      elsif str =~ /\A([a-zA-Z ]+)(\+*)\Z/
        node = find_node_by_shortcut($1,$2.size)
        node ? node[sym] : nil
      else
        nil
      end
    end
    
    def create_or_update_node(new_attributes)
      attributes = transform_attributes(new_attributes)
      unless attributes['name'] && attributes['parent_id']
        node = Node.new
        node.errors.add('name', "can't be blank") unless attributes['name']
        node.errors.add('parent_id', "can't be blank") unless attributes['parent_id']
        return node
      end
      node = Node.with_exclusive_scope do
        Node.find(:first, :conditions => ['site_id = ? AND name = ? AND parent_id = ?', 
                                          current_site[:id], attributes['name'].url_name, attributes['parent_id']])
      end
      if node
        visitor.visit(node) # secure
        # TODO: class ignored (could be used to transform from one class to another...)
        attributes.delete('class')
        attributes.delete('klass')
        node.edit!(attributes['v_lang'])
        node.update_attributes(attributes)
      else
        node = create_node(new_attributes)
      end
      node
    end
    
    # TODO: cleanup and rename with something indicating the attrs cleanup that this method does.
    def create_node(new_attributes)
      attributes = transform_attributes(new_attributes)
      
      publish_after_save = (attributes.delete('v_status').to_i == Zena::Status[:pub])  # the way this works here and in do_update_attributes is not good
      
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
        klass.with_exclusive_scope(scope) { klass.create_instance(attributes) }
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
          if filename =~ /\.tgz$|\.tar$/
            `tar -C '#{folder}' -xz < '#{archive.path}'`
          elsif filename =~ /\.zip$/
            `unzip -d '#{folder}' '#{archive.path}'`
          elsif filename =~ /(.*)(\.gz|\.z)$/
            `gzip -d '#{archive.path}' -c > '#{folder}/#{$1.gsub("'",'')}'`
          else
            # FIXME: send errors back
            puts "BAD #{archive.inspect}"
          end
          res = create_nodes_from_folder(:folder => folder, :parent_id => parent_id, :defaults => defaults)
        ensure
          FileUtils::rmtree(folder)
        end
        return res
      end
      
      entries = Dir.entries(folder).reject { |f| f =~ /^[^\w]/ }.sort

      index  = 0

      while entries[index]
        type = current_obj = sub_folder = document_path = nil
        versions = []
        filename = entries[index]
        if filename =~ /^[\._~]/
          index += 1
          next
        end
        
        path     = File.join(folder, filename)

        if File.stat(path).directory?
          type   = :folder
          name   = filename
          sub_folder = path
        elsif filename =~ /^(.+?)(\.\w\w|)(\.\d+|)\.yml$/
          type   = :node
          name   = $1
          lang   = $2.blank? ? visitor.lang : $2[1..-1]
          attrs  = defaults.merge(get_attributes_from_yaml(path))
          attrs['name']     = name
          attrs['v_lang'] ||= lang
          versions << attrs
        else
          type   = :document
          name   = filename
          document_path = path
        end
        
        index += 1
        while entries[index] =~ /^#{name}(\.\w\w|)(\.\d+|)\.yml$/
          lang   = $1.blank? ? visitor.lang : $1[1..-1]
          path   = File.join(folder,entries[index])
          
          # we have a yml file. Create a version with this file
          attrs = defaults.merge(get_attributes_from_yaml(path))
          attrs['name']     = name
          attrs['v_lang'] ||= lang
          versions << attrs
          
          index += 1
        end
        
        if versions.empty? 
          if type == :folder
            # minimal node for a folder
            attrs = defaults.dup
            attrs['name']     = name
            attrs['v_lang'] ||= lang
            attrs['class']    = 'Page'
            versions << attrs
          elsif type == :document
            # minimal node for a folder
            attrs = defaults.dup
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
            attrs['c_ext'] = attrs['name'].split('.').last
            attrs['name' ] = attrs['name'].split('.')[0..-2].join('.')
            if document_path
              # file
              ctype = EXT_TO_TYPE[document_path.split('.').last][0] || "application/octet-stream"
              
              File.open(document_path) do |file|
                (class << file; self; end;).class_eval do
                  alias local_path path if defined?(:path)
                  define_method(:original_filename) { filename }
                  define_method(:content_type) { ctype }
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

        res.merge!(create_nodes_from_folder(:folder => sub_folder, :parent_id => current_obj[:id], :defaults => defaults)) if sub_folder && !current_obj.new_record?
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
        Node.with_exclusive_scope do
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

    # Find a node's zip based on a query shortcut. Used by zazen to create a link for ""::art for example.
    def find_node_by_shortcut(string,offset=0)
      with_exclusive_scope(self.scoped_methods[0] || {}) do
        find(:first, Node.match_query(string.gsub('-',' '), :offset => offset))
      end
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
      elsif query != ''
        if RAILS_ENV == 'test'
          match = sanitize_sql(["vs.title LIKE ? OR nodes.name LIKE ?", "%#{query}%", "#{query}%"])
          select = "nodes.*, #{match} AS score"
        else
          match  = sanitize_sql(["MATCH (vs.title,vs.text,vs.summary) AGAINST (?) OR nodes.name LIKE ?", query, "#{opts[:name_query] || query.url_name}%"])
          select = sanitize_sql(["nodes.*, MATCH (vs.title,vs.text,vs.summary) AGAINST (?) + (5 * (nodes.name LIKE ?)) AS score", query, "#{query}%"])
        end
        return opts.merge(
          :select => select,
          # version join should be the same as in HasRelations#build_condition
          :joins  => "INNER JOIN versions AS vs ON vs.node_id = nodes.id AND ((vs.status >= #{Zena::Status[:red]} AND vs.user_id = #{visitor[:id]} AND vs.lang = '#{visitor.lang}') OR vs.status > #{Zena::Status[:red]})",
          :conditions => match,
          :group      => "nodes.id",
          :order  => "score DESC")
      else
        # error
        raise Exception.new('bad arguments for search ("query" field missing)')
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
        relation = Relation.find_by_role(rel.singularize)
        return false unless relation
        relation.target_role == rel.singularize ? !relation.target_unique : !relation.source_unique
      end
    end 
    
    # Translate attributes from the visitor's reference to the application.
    # This method translates dates, zazen shortcuts and zips and returns a stringified hash.
    def transform_attributes(new_attributes)
      parent_id  = new_attributes[:_parent_id] # real id set inside zena.
      attributes = new_attributes.stringify_keys
      attributes.delete('_parent_id')

      if parent_id
        attributes.delete('parent_id')
      elsif p = attributes.delete('parent_id')
        parent_id = Node.translate_pseudo_id(p) || p
      end

      attributes.keys.each do |key|
        if ['rgroup_id', 'wgroup_id', 'pgroup_id', 'user_id'].include?(key)
          # ignore
        elsif ['v_publish_from', 'log_at', 'event_at'].include?(key)
          # parse date
          attributes[key] = attributes[key].to_utc(_('datetime'), visitor.tz)
        elsif key =~ /^(\w+)_id$/
          if key[0..1] == 'd_'
            attributes[key] = Node.translate_pseudo_id(attributes[key],:zip) || attributes[key]
          else
            attributes[key] = Node.translate_pseudo_id(attributes[key]) || attributes[key]
          end
        elsif key =~ /^(\w+)_ids$/
          # Id list. Bad ids are removed.
          values = attributes[key].kind_of?(Array) ? attributes[key] : attributes[key].split(',')
          if key[0..1] == 'd_'
            values.map! {|v| Node.translate_pseudo_id(v,:zip) }
          else
            values.map! {|v| Node.translate_pseudo_id(v,:id ) }
          end
          attributes[key] = values.compact
        else
          # translate zazen
          value = attributes[key]
          if value.kind_of?(String)
            attributes[key] = ZazenParser.new(value,:helper=>self, :node=>self).render(:parse_shortcuts=>true)
          end
        end
      end


      attributes['parent_id'] = parent_id if parent_id

      attributes.delete('file') if attributes['file'] == ''

      attributes
    end

    def get_attributes_from_yaml(filepath)
      attributes = {}
      YAML::load_documents( File.open( filepath ) ) do |entries|
        entries.each do |key,value|
          attributes[key] = value
        end
      end
      attributes
    end
    
    # Return a safe string to access node attributes in compiled templates and compiled sql.
    def zafu_attribute(node, attribute)
      case attribute[0..1]
      when 'v_'
        att = attribute[2..-1]
        if Version.zafu_readable?(att)
          "#{node}.version.#{att}"
        else
          # might be readable by sub-classes
          "#{node}.version.zafu_read(#{attribute[2..-1].inspect})"
        end
      when 'c_'
        "#{node}.c_zafu_read(#{attribute[2..-1].inspect})"
      when 'd_'
        "#{node}.version.dyn[#{attribute[2..-1].inspect}]"
      else
        if Node.zafu_readable?(attribute)
          "#{node}.#{attribute}"
        else
          # unknown attribute for Node, resolve at runtime with real class
          "#{node}.zafu_read(#{attribute.inspect})"
        end
      end
    end
  end
  
  def visitor
    return @visitor if @visitor
    raise Zena::RecordNotSecured.new("Visitor not set, record not secured.")
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
    vclass.to_s
  end
  
  def klass=(str)
    # TODO: set @new_klass... and transform
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
    update_attributes(Node.transform_attributes(new_attributes))
  end
  
  # Filter attributes before assignement.
  # Set name from version title if no name set yet.
  def filter_attributes(attributes)
    if self[:name].blank? && attributes['name'].blank? && attributes['v_title']
      attributes.merge('name' => attributes['v_title'])
    else
      attributes
    end
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
  def fullpath(rebuild=false, update = true)
    if !self[:fullpath] || rebuild
      if parent = parent(false)
        path = parent.fullpath(rebuild).split('/') + [name.gsub("'",'')]
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
  
  
  # Return save path for an asset (element produced by text like a png file from LateX)
  def asset_path(asset_filename)
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
    return self if self[:parent_id].nil?
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
    c.pgroup_id  = self.pgroup_id
    
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
    @icon = do_find(:first, eval("\"#{Node.build_find(:first, ['icon', 'image'], 'self')}\""))
  end
  
  alias o_user user
  
  def user
    secure!(User) { o_user }
  end
  
  # Find all data entries linked to the current node
  def data
    DataEntry.find(:all, :conditions => "node_a_id = #{id} OR node_b_id = #{id} OR node_c_id = #{id} OR node_d_id = #{id}")
  end
  
  # Find data entries through a specific slot (node_a, node_b). "data_entries_a" finds all data entries link through 'node_a_id'.
  DataEntry::NodeLinkSymbols.each do |sym|
    class_eval "def #{sym.to_s.gsub('node', 'data')}
      return [] if new_record?
      DataEntry.find(:all, :conditions=>\"#{sym}_id = '\#{self[:id]}'\")
    end"
  end
  
  def ext
    (name && name != '' && name =~ /\./ ) ? name.split('.').last : ''
  end
  
  def c_zafu_read(sym)
    if c = version.content
      c.zafu_read(sym)
    else
      ''
    end
  end
    
  # set name: remove all accents and camelize
  def name=(str)
    return unless str && str != ""
    self[:name] = str.url_name
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
    parent[:zip]
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

  # Find the discussion for the current context (v_status and v_lang). This automatically creates a new #Discussion if there
  # already exists an +outside+, +open+ discussion for another language.
  # TODO: update tests with visitor status.
  def discussion
    @discussion ||= Discussion.find(:first, :conditions=>[ "node_id = ? AND inside = ? AND lang = ?", 
                    self[:id], v_status != Zena::Status[:pub], v_lang ]) ||
          if ( v_status != Zena::Status[:pub] ) ||
             ( Discussion.find(:first, :conditions=>[ "node_id = ? AND inside = ? AND open = ?", 
                                     self[:id], false, true ]))
            # v_status is not :pub or we already have an outside, open discussion for this node             
            # => we can create a new one
            Discussion.new(:node_id=>self[:id], :lang=>v_lang, :inside=>(v_status != Zena::Status[:pub]))
          else
            nil
          end
  end
  
  # Comments for the current context. Returns [] when none found.
  def comments
    if discussion
      discussion.comments(:with_prop=>can_drive?)
    else
      []
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
  # TODO: update test with 'commentator?'
  def can_comment?
    visitor.commentator? && discussion && discussion.open?
  end
  
  # Add a comment to a node. If reply_to is set, the comment is added to the proper message
  def add_comment(opt)
    return nil unless can_comment?
    discussion.save if discussion.new_record?
    author = opt[:author_name] = nil unless visitor.is_anon? # anonymous user
    opt.merge!( :discussion_id=>discussion[:id], :user_id=>visitor[:id] )
    secure!(Comment) { Comment.create(opt) }
  end
  
  # TODO: test
  def sweep_cache
    return if current_site.being_created?
    # zafu 'erb' rendering cache expire
    # TODO: expire only 'dev' rendering if version is a redaction
    CachedPage.expire_with(self) if self.kind_of?(Template)
    
    # Clear element cache
    Cache.sweep(:visitor_id=>self[:user_id], :visitor_groups=>[rgroup_id, wgroup_id, pgroup_id], :kpath=>self.vclass.kpath)
    
    # Clear full result cache
    
    # we want to be sure to find the project and parent, even if the visitor does not have an
    # access to these elements.
    # FIXME: use self + modified relations instead of parent/project
    [self, self.real_project(false), self.real_section(false), self.parent(false)].compact.uniq.each do |obj|
      # destroy all pages from project, parent and section !
      CachedPage.expire_with(obj)
      # this destroys less cache but might miss things like 'changes in project' that are displayed on every page.
      # CachedPage.expire_with(self, [self[:project_id], self[:section_id], self[:parent_id]].compact.uniq)
    end
    
    # clear assets
    FileUtils::rmtree(asset_path(''))
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
      
      # set name from version title if name not set yet
      self.name = version[:title] unless self[:name]
      
      if self[:name]
        # update cached fullpath
        if new_record? || self[:name] != old[:name] || self[:parent_id] != old[:parent_id]
          self[:fullpath] = self.fullpath(true,false)
        elsif !new_record? && self[:custom_base] != old[:custom_base]
          self[:basepath] = self.basepath(true,false)
        end
      end

      # make sure section is the same as the parent
      if self[:parent_id].nil?
        # root node
        self[:section_id] = nil
        self[:project_id] = nil
      elsif parent
        self[:section_id] = parent.get_section_id
        self[:project_id] = parent.get_project_id
      else
        # bad parent will be caught later.
      end

      
      if !new_record? && self[:parent_id]
        # node updated and it is not the root node
        if !kind_of?(Section) && self[:section_id] != old[:section_id]
          @spread_section_id = self[:section_id]
        end
        if !kind_of?(Project) && self[:project_id] != old[:project_id]
          @spread_project_id = self[:project_id]
        end
        
      end
    end

    # Make sure the node is complete before creating it (check parent and project references)
    def validate_node
      # when creating root node, self[:id] and :root_id are both nil, so it works.
      errors.add("parent_id", "invalid parent") unless (parent.kind_of?(Node) && self[:id] != current_site[:root_id]) || (self[:id] == current_site[:root_id] && self[:parent_id] == nil)
      
      errors.add("name", "can't be blank") unless self[:name] and self[:name] != ""
      
      errors.add("version", "can't be blank") if new_record? && !@version
    end
    
    # Called before destroy. An node must be empty to be destroyed
    def node_on_destroy
      unless empty?
        errors.add('base', "contains subpages")
        return false
      else  
        # expire cache
        # TODO: test
        CachedPage.expire_with(self)
        return true
      end
    end
  
    # Get unique zip in the current site's scope
    def node_before_create
      self[:zip] = Node.next_zip(self[:site_id])
    end
    
    # Called after a node is 'unpublished'
    def after_unpublish
      if (self[:max_status] < Zena::Status[:pub]) && !@new_record_before_save
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
    def after_publish(pub_time=nil)
      return true if @new_record_before_save
      sync_documents(:publish, pub_time)
    end

    # Publish, refuse, propose the Documents of a redaction
    def sync_documents(action, pub_time=nil)
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
            doc.errors.each do |err|
              errors.add('document', err.to_s)
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
      true
    end
  
    # Find all children, whatever visitor is here (used to check if the node can be destroyed or to update section_id)
    def all_children
      Node.with_exclusive_scope do
        Node.find(:all, :conditions=>['parent_id = ?', self[:id] ])
      end
    end
  
    # Set owner and lang before validations on create (overwritten by multiversion)
    def set_on_create
      super
      # set kpath 
      self[:kpath] = self.vclass.kpath
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