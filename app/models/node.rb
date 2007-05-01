=begin rdoc
A Node is the root class of all elements in the zena application. Actual class inheritance diagram:

Node (manages access and publication cycle)
  |
  +-- Page (web pages)
  |     |
  |     +--- Document
  |     |      |
  |     |      +--- Image
  |     |      |
  |     |      +--- TextDocument       (for css, scripts)
  |     |             |
  |     |             +--- Partial     (uses the zafu templating language)
  |     |                    |
  |     |                    +--- Template  (entry for rendering)
  |     |
  |     +--- Project (has it's own project_id. Can contain notes, collaborators, etc)
  |     |
  |     +--- Section (has it's own section_id = group of pages)
  |            |
  |            +--- Skin (theme: contains css, templates, etc)
  |
  +-- Note (date related information, event)
  |     |
  |     +--- Post
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
  has_many           :discussions
  has_and_belongs_to_many :cached_pages
  before_validation  :node_before_validation
  validate           :validate_node
  before_save        :node_before_create
  after_save         :spread_project_and_section
  before_destroy     :node_on_destroy
  attr_protected     :site_id, :zip, :id, :section_id, :project_id, :publish_from, :max_status
  acts_as_secure_node
  acts_as_multiversioned
  link :tags, :class_name=>'Tag'
  link :references, :class_name=>'Reference'
  link :icon, :class_name=>'Image', :unique=>true
  link :hot_for,  :as=>'hot' , :class_name=>'Project', :as_unique=>true
  link :home_for, :as=>'home', :class_name=>'Project', :as_unique=>true
  
  class << self
    
    # TODO: cleanup and rename with something indicating the attrs cleanup that this method does.
    def create_node(attrs)
      scope   = self.scoped_methods[0] || {}
      visitor = scope[:create][:visitor]
      klass = attrs.delete('class') || attrs.delete('klass') || attrs.delete(:class) || attrs.delete(:klass) || self.to_s
      
      if parent_id = attrs.delete(:_parent_id)
        attrs.delete('parent_id')
      else
         p = attrs['parent_id']
        if p && p.to_i.to_s != p.to_s.strip
          # find by name
          parent_id = Node.with_exclusive_scope(scope) { Node.find_by_name(p) }[:id]
          attrs.delete('parent_id')
        end
      end

      attrs.keys.each do |key|
        if key.to_s =~ /^(\w+)_id$/ && ! ['rgroup_id', 'wgroup_id', 'pgroup_id', 'user_id'].include?(key.to_s)
          attrs[key] = Node.connection.execute( "SELECT id FROM nodes WHERE site_id = #{visitor.site[:id]} AND zip = '#{attrs[key].to_i}'" ).fetch_row[0]
        end
      end

      attrs['parent_id'] = parent_id if parent_id

      attrs.delete('file') if attrs['file'] == ''

      klass = Module::const_get(klass.to_sym)
      raise NameError unless klass.ancestors.include?(Node)
      if klass != self
        klass.with_exclusive_scope(scope) { klass.create(attrs) }
      else
        self.create(attrs)
      end
    rescue NameError => err
      node = self.new
      node.instance_eval { @attributes = attrs }
      node.errors.add('klass', 'invalid')
      # This is to show the klass in the form seizure
      node.instance_variable_set(:@klass, klass)
      def node.klass; @klass; end
      node
    end
    
    
    def create_nodes_from_folder(opts)
      return nil unless (opts[:folder] || opts[:archive]) && (opts[:parent] || opts[:parent_id])
      scope = self.scoped_methods[0] || {}
      parent_id = opts[:parent_id] || opts[:parent][:id]
      folder    = opts[:folder]
      defaults  = opts[:defaults] || {}
      
      # create from archive
      unless folder
        archive = File.new(opts[:archive])
        n       = 0
        while true
          folder = File.join(RAILS_ROOT, 'tmp', sprintf('%s.%d.%d', 'import', $$, n))
          break unless File.exists?(folder)
        end

        begin
          FileUtils::mkpath(folder)
          # extract file in this temporary folder.
          # FIXME: is there a security risk here ?
          system "tar -C '#{folder}' -xz < '#{archive.path}'"
          res = create_nodes_from_folder(:folder => folder, :parent_id => parent_id, :defaults => defaults)
        ensure
          FileUtils::rmtree(folder)
        end
        return res
      end
 

      entries = Dir.entries(folder).reject { |f| f =~ /^[^\w]/ }

      index  = 0

      while index < entries.size
        current_obj = document = sub_folder = nil # new object
        filename = entries[index]
        path     = File.join(folder, filename)

        if File.stat(path).directory?
          sub_folder = path
          # look-ahead to see if we have any related yml files before processing the folder
        elsif filename =~ /^(.+)(\.\w\w|)(\.\d+|)\.yml$/  
          name, lang = $1, ($2 ? $2[1..-1] : visitor.lang)
          # yaml node
          attrs = defaults.merge(get_attributes_from_yaml(path)).merge(:_parent_id => parent_id)
          attrs['name']   ||= name
          attrs['v_lang'] ||= lang
          current_obj = create_node(attrs)
        else
          # document
          document   = path
          # look-ahead
        end  
        index += 1

        # FIXME: how to set version status and user_id ?

        while entries[index] =~ /^#{filename}(\.\w\w|)(\.\d+|)\.yml$/
          lang = $1 ? $1[1..-1] : visitor.lang

          # we have a yml file. Create a version with this file
          attrs = defaults.merge(get_attributes_from_yaml(File.join(folder,entries[index])))
          attrs['name']   ||= filename.split('.').first
          attrs['v_lang'] ||= lang

          if current_obj
            # FIXME: what publication status for these things ?
            current_obj.remove if current_obj.v_lang == attrs['v_lang']
            current_obj.edit!(attrs['v_lang'])
            # FIXME: This should pass through the 'attrs' cleanup...
            current_obj.update_attributes(attrs.merge(:parent_id => parent_id))
          elsif document
            # processing a document
            ctype = EXT_TO_TYPE[document.split('.').last][0] || "application/octet-stream"
            File.open(document) do |file|
              (class << file; self; end;).class_eval do
                alias local_path path if defined?(:path)
                define_method(:original_filename) { filename }
                define_method(:content_type) { ctype }
              end
              current_obj = create_node(attrs.merge(:c_file => file, :klass => 'Document', :_parent_id => parent_id))
            end
            document = nil
          else
            # processing a folder
            current_obj = create_node(attrs.merge(:_parent_id => parent_id))
          end
          index += 1
        end

        # finished with the current object's yaml
        if sub_folder
          # create minimal object to store the children
          current_obj ||= Page.with_exclusive_scope(scope) { Page.create( defaults.merge(:parent_id => parent_id, :name => filename.split('.').first) )}
          create_nodes_from_folder(:folder => sub_folder, :parent_id => current_obj[:id], :defaults => defaults)
        elsif document && !current_obj  
          # processing a document
          # TODO: DRY this someday...
          ctype = EXT_TO_TYPE[document.split('.').last][0] || "application/octet-stream"
          File.open(document) do |file|
            (class << file; self; end;).class_eval do
              alias local_path path if defined?(:path)
              define_method(:original_filename) { filename }
              define_method(:content_type) { ctype }
            end
            current_obj = Document.with_exclusive_scope(scope) { Document.create(defaults.merge(:c_file => file, :parent_id => parent_id, :name => filename)) }
          end
        end
      end
      current_obj
    end


    # valid parent class
    def parent_class
      Node
    end
    
    def find_by_zip(zip)
      node = find(:first, :conditions=>"zip = #{zip.to_i}")
      raise ActiveRecord::RecordNotFound unless node
      node
    end
    
    # Find an node by it's full path. Cache 'fullpath' if found.
    def find_by_path(path)
      return nil unless scope = scoped_methods[0]
      return nil unless scope[:create]
      visitor = scoped_methods[0][:create][:visitor] # use secure scope to get visitor
      node = self.find_by_fullpath(path)
      if node.nil?
        path = path.split('/')
        last = path.pop
        Node.with_exclusive_scope do
          node = Node.find(visitor.site[:root_id])
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
    
    def get_attributes_from_yaml(filepath)
      attributes = {}
      YAML::load_documents( File.open( filepath ) ) do |entries|
        entries.each do |key,value|
          attributes[key] = value
        end
      end
      attributes
    end
  end
  
  # Return the class name of the node (used by forms)
  def klass
    self.class.to_s
  end
  
  # Return the list of ancestors (without self): [root, obj, obj]
  # ancestors to which the visitor has no access are removed from the list
  def ancestors(start=[])
    raise Zena::InvalidRecord, "Infinit loop in 'ancestors' (#{start.inspect} --> #{self[:id]})" if start.include?(self[:id]) 
    start += [self[:id]]
    if self[:id] == visitor.site[:root_id]
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
  rescue ActiveRecord::RecordNotFound
    []
  end
  
  # url base path. cached. If rebuild is set to true, the cache is updated.
  def basepath(rebuild=false)
    if !rebuild && self[:basepath]
      self[:basepath]
    else
      if self[:parent_id]
        parent = @parent || Node.with_exclusive_scope { Node.find_by_id(self[:parent_id]) }
        path = parent ? parent.basepath : ''
      else
        path = ''
      end
      self.connection.execute "UPDATE #{self.class.table_name} SET basepath='#{path.gsub("'",'')}' WHERE id='#{self[:id]}'"
      path
    end
  end

  # Return the full path as an array if it is cached or build it when asked for.
  def fullpath
    if self[:fullpath]
      self[:fullpath]
    else
      if parent = parent(:secure=>false)
        path = parent.fullpath.split('/') + [name]
      else
        path = []
      end
      self.connection.execute "UPDATE #{self.class.table_name} SET fullpath='#{path.join('/').gsub("'",'')}' WHERE id='#{self[:id]}'"
      path.join('/')
    end
  end
  
  # Same as fullpath, but the path includes the root node.
  def rootpath
    ZENA_ENV[:site_name] + (fullpath != "" ? "/#{fullpath}" : "")
  end
  
  
  def relation_methods
    ['root', 'project', 'section', 'parent', 'self', 'nodes', 'projects', 'sections', 'children', 'pages', 'documents', 'documents_only', 'images', 'notes', 'author', 'traductions', 'versions']
  end
  
  # This is defined by the linkable lib, we add access to 'root', 'project', 'parent', 'children', ...
  def relation(methods, opts={})
    res = nil
    try_list = methods.split(',')
    plural = Zena::Acts::Linkable::plural_method?(try_list[0])
    if !plural
      opts[:limit] = 1
    end
    while (!res || res==[]) && try_list != []
      method = try_list.shift
      begin
        if method =~ /\A\d+\Z/
          res = secure(Node) { Node.find(method) }
        else
          if relation_methods.include?(method)
            if method == 'self'
              res = self
            elsif Zena::Acts::Linkable::plural_method?(method)
              res = self.send(method.to_sym, opts)
            elsif opts[:from]
              if res = self.send(method.to_sym)
                res = [res]
              end
            else
              res = self.send(method.to_sym)
            end
          else
            # Find through Linkable
            res = fetch_link(method, opts)
          end
        end
      rescue ActiveRecord::RecordNotFound
        res = nil
      end
    end
    if res
      if plural && !res.kind_of?(Array)
        [res]
      elsif !plural && res.kind_of?(Array)
        res[0]
      else
        res
      end
    else
      nil
    end
  end
  
  
  def relation_options(opts, cond=nil)
    case opts[:from]
    when 'site'
      conditions = "1"
    when 'project'
      conditions = ["project_id = ?", self[:project_id]]
    when 'section'
      conditions = ["section_id = ?", self[:section_id]]
    else
      # self or nothing
      conditions = ["parent_id = ?", self[:id]]
    end
    opts.delete(:from)
    if cond
      # merge option and condition
      if conditions.kind_of?(Array)
        conditions[0] = "(#{conditions[0]}) AND (#{cond})"
      else  
        conditions = "(#{conditions}) AND (#{cond})"
      end
    end
    if opt_cond = opts[:conditions]
      if opt_cond.kind_of?(Array)
        # merge option and condition
        if conditions.kind_of?(Array)
          conditions[0] = "(#{conditions[0]}) AND (#{opt_cond[0]})"
        else
          conditions = ["(#{conditions}) AND (#{opt_cond[0]})", *opt_cond[1..-1]]
        end
      else
        # merge option and condition
        if conditions.kind_of?(Array)
          conditions[0] = "(#{conditions[0]}) AND (#{opt_cond})"
        else
          conditions = "(#{conditions}) AND (#{opt_cond})"
        end
      end
    end
    opts.delete(:conditions)
    {:order=>'name ASC', :conditions=>conditions}.merge(opts)
  end
  
  # Get root node
  def root(opts={})
    secure(Node) { Node.find(visitor.site[:root_id])}
  rescue ActiveRecord::RecordNotFound
    nil
  end
  
  # Find all children
  def children(opts={})
    @children ||= secure(Node) { Node.find(:all, relation_options(opts)) }
  end
  
  # Find notes (overwritten in Project)
  def notes
    nil
  end
  
  # Find parent
  def parent(opts={})
    @parent ||= secure(Node, opts) { Node.find(self[:parent_id]) }
  rescue ActiveRecord::RecordNotFound
    nil
  end
  
  # Find section
  def section(opts={})
    # we cannot use Section to find because the root node behaves like a Section but is a Project.
    secure(Node, opts) { Node.find(self[:section_id]) }
  rescue ActiveRecord::RecordNotFound
    nil
  end
  
  # Find project
  def project(opts={})
    secure(Project, opts) { Project.find(self[:project_id]) }
  rescue ActiveRecord::RecordNotFound
    nil
  end
  
  # Find sections (sections from='site')
  def sections(opts={})
    opts[:from] ||= 'project'
    secure(Section) { Section.find(:all, relation_options(opts)) }
  rescue ActiveRecord::RecordNotFound
    nil
  end
  
  # Find projects (projects from='site')
  def projects(opts={})
    opts[:from] ||= 'project'
    secure(Project) { Project.find(:all, relation_options(opts)) }
  rescue ActiveRecord::RecordNotFound
    nil
  end
  
  # Find all sub-nodes (all children / all nodes in a section)
  def nodes(opts={})
    @nodes ||= secure(Node) { Node.find(:all, relation_options(opts)) }
  end
  
  # Find all sub-pages (All but documents)
  def pages(opts={})
    @pages ||= secure(Page) { Page.find(:all, relation_options(opts,"kpath NOT LIKE 'NPD%'")) }
  end
  
  # Find documents
  def documents(opts={})
    @documents ||= secure(Document) { Document.find(:all, relation_options(opts)) }
  end

  # Find documents without images
  def documents_only(opts={})
    @doconly ||= secure(Document) { Document.find(:all, relation_options(opts, "kpath NOT LIKE 'NPDI%'") ) }
  end
  
  # Find only images
  def images(opts={})
    @images ||= secure(Image) { Image.find(:all, relation_options(opts) ) }
  end
  
  # Find only notes
  def notes(opts={})
    @notes ||= secure(Note) { Note.find(:all, relation_options(opts) ) }
  end
 
  # Find all trackers
  def trackers(opts={})
    @trackers ||= secure(Tracker) { Tracker.find(:all, relation_options(opts) ) }
  end
  
  # Create a child and let him inherit from rwp groups and section_id
  def new_child(opts={})
    klass = opts.delete(:class) || Page
    c = klass.new(opts)
    c.parent_id  = self[:id]
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
    user
  end
  
  def author_id
    user_id
  end
  
  def ext
    (name && name != '' && name =~ /\./ ) ? name.split('.').last : ''
  end
    
  # set name: remove all accents and camelize
  def name=(str)
    return unless str && str != ""
    self[:name] = camelize(str)
  end
  
  # Return self[:id] if the node is a kind of Section. Return section_id otherwise.
  def get_section_id
    return self[:id] if self[:parent_id].nil? # root node is it's own section and project
    self.kind_of?(Section) ? self[:id] : self[:section_id]
  end
  
  # Return self[:id] if the node is a kind of Project. Return project_id otherwise.
  def get_project_id
    return self[:id] if self[:parent_id].nil? # root node is it's own section and project
    self.kind_of?(Project) ? self[:id] : self[:project_id]
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
  
  # More reflection needed before implementation.
  
  # transform an Node into another Object. This is a two step operation :
  # 1. create a new object with the attributes from the old one
  # 2. move old object out of the way (setting parent_id and section_id to -1)
  # 3. try to save new object
  # 4. delete old and set new object id to old
  # THIS IS DANGEROUS !! NEEDS TESTING
  # def change_to(klass)
  #   return nil if self[:id] == visitor.site[:root_id]
  #   # ==> Check for class specific information (file to remove, participations, tags, etc) ... should we leave these things and
  #   # not care ?
  #   # ==> When changing into something else : update version type and data !!!
  #   my_id = self[:id].to_i
  #   my_parent = self[:parent_id].to_i
  #   my_project = self[:section_id].to_i
  #   connection = self.class.connection
  #   # 1. create a new object with the attributes from the old one
  #   new_obj = secure(klass) { klass.new(self.attributes) }
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
  
  # Return true if it is allowed to add comments to the node in the current context
  # TODO: update test with 'commentator?'
  def can_comment?
    visitor.commentator? && discussion && discussion.open?
  end
  
  # Add a comment to an node. If reply_to is set, the comment is added to the proper message
  def add_comment(opt)
    return nil unless can_comment?
    discussion.save if discussion.new_record?
    author = opt[:author_name] = nil unless visitor[:id] == 1 # anonymous user
    opt.merge!( :discussion_id=>discussion[:id], :user_id=>visitor[:id] )
    secure(Comment) { Comment.create(opt) }
  end
  
  # TODO: test
  def sweep_cache
    return unless Cache.perform_caching
    Cache.sweep(:visitor_id=>self[:user_id], :visitor_groups=>[rgroup_id, wgroup_id, pgroup_id], :kpath=>self.class.kpath)
    return unless  self.public? || old.public? # is/was visible to anon user
    # we want to be sure to find the project and parent, even if the visitor does not have an
    # access to these elements.
    # FIXME: use self + modified relations instead of parent/project
    [self, self.section(:secure=>false), self.parent(:secure=>false)].compact.uniq.each do |obj|
      CachedPage.expire_with(obj)
    end
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
      # remove cached fullpath
      self[:fullpath] = nil

      # make sure section is the same as the parent
      if self[:parent_id].nil?
        # root node
        self[:section_id] = self[:id]
        self[:project_id] = self[:id]
      elsif parent
        self[:section_id] = parent.get_section_id
        self[:project_id] = parent.get_project_id
      else
        # bad parent will be caught later.
      end

      # set name from title if name not set yet
      self.name = version[:title] unless self[:name]
      
      if !new_record?
        if self[:section_id] != old[:section_id]
          @spread_section_id = self[:section_id]
        end
        if self[:project_id] != old[:project_id]
          @spread_project_id = self[:project_id]
        end
        
      end
    end

    # Make sure the node is complete before creating it (check parent and project references)
    def validate_node
      # when creating root node, self[:id] and :root_id are both nil, so it works.
      errors.add("parent_id", "invalid parent") unless parent.kind_of?(self.class.parent_class) || (self[:id] == visitor.site[:root_id] && self[:parent_id] == nil)
      
      errors.add("name", "can't be blank") unless self[:name] and self[:name] != ""
      
      errors.add("version", "can't be blank") if new_record? && !@version
    end
    
    # Called before destroy. An node must be empty to be destroyed
    def node_on_destroy
      unless all_children.size == 0
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
      self[:zip] ||= Node.next_zip(self[:site_id])
    end
    
    # Called after an node is 'removed'
    def after_remove
      if self[:max_status] < Zena::Status[:pub]
        # not published any more. 'remove' documents
        sync_documents(:remove)
      else
        true
      end
    end
  
    # Called after an node is 'proposed'
    def after_propose
      sync_documents(:propose)
    end
  
    # Called after an node is 'refused'
    def after_refuse
      sync_documents(:refuse)
    end
  
    # Called after an node is published
    def after_publish(pub_time=nil)
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
      when :refuse
        documents.each do |doc|
          if doc.can_refuse?
            allOK = doc.refuse && allOK
          end
        end
      when :publish
        documents.each do |doc|
          if doc.can_publish?
            allOK = doc.publish(pub_time) && allOK
          end
        end
      when :remove
        # FIXME: use a 'before_remove' callback to make sure all sub-nodes can be removed...
        documents.each do |doc|
          unless doc.remove
            doc.errors.each do |err|
              errors.add('document', err.to_s)
            end
            allOK = false
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
  
    def camelize(str)
      str = str.dup
      accents = { 
        ['á',    'à','À','â','Â','ä','Ä','ã','Ã'] => 'a',
        ['é','É','è','È','ê','Ê','ë','Ë',       ] => 'e',
        ['í',    'ì','Ì','î','Î','ï','Ï'        ] => 'i',
        ['ó',    'ò','Ò','ô','Ô','ö','Ö','õ','Õ'] => 'o',
        ['ú',    'ù','Ù','û','Û','ü','Ü'        ] => 'u',
        ['œ'] => 'oe',
        ['ß'] => 'ss',
        }
      accents.each do |ac,rep|
        ac.each do |s|
          str.gsub!(s, rep)
        end
      end
      str.gsub!(/[^a-zA-Z0-9_\. ]/," ")
      str = str.split.join(" ")
      str.gsub!(/ (.)/) { $1.upcase }
      str
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
      if !for_heirs && (self[:id] == visitor.site[:root_id])
        :id # root is it's own reference
      else
        :parent_id
      end
    end
end