=begin rdoc
An Node is the parent for all web content classes (#Page, #Event, #Log, #Document, #Category, #Project).

== #Note vs #Page vs #Documents
A #Note is something related to *time* for a certain #Project. A #Page is some structured data organised as a tree.
A note's parent can only be a Project. A page's parent can be any kind of #Page. There is a special case for documents. A #Document
can have a #Note as parent and it cannot have children.

== Secure access
See #Zena::Acts::Secure

== Editions vs Versions
An edition is a _published_ version. An node can only have one edition per language. If there is no edition
available in the current language the +ref_lang+ edition is shown instead. If the latter does not exist any
edition is shown.

If an node does not have any editions : it <i>does not exist</i>. It will appear nowhere. Only it's current versions
will show up as <i>working copies</i> on the user's home page.

Changing versions (rollback, rollforward) is done by first choosing 'manage' action. This action shows a list of versions for 
the current language (in node_actions). There should be a possibility to change lang or show all. Each line has 'show' 
(live_preview). Once the version is shown: 'rollxxx', 'show_diff'.

Here is a drawing of version status :
link://../img/zena_versions_life.png

= Node life cycle

== New
link://../img/zena_new_node.png

== Publication
There can only be one published version per language. The published_at date is set to some datetime in the future or
simply to +now+. The publication date cannot be set to a moment in the past (it should only be used to make the node appear
on the site at a specified date). This ensures that we can see how the site was, somewhere in the past.

Setting a #Version from +red+ to +prop+ proposes to change all children (status=red, same owner) to 'prop'.
Publishing a #Version proposes to publish all children (status=prop, same owner).

== Display
When an node is displayed, it shows it's edition and some other element :
[contact] If the node is a presentation page for a contact : display contact partial
[document] If the node is a #Document : display preview and link for download.
[book] Display a book reference if there is one.
[action] Depending on user rights, display buttons to 'edit, add, remove' node.

= Relation to project
This part is not very clear yet. A Note must have a project as this is it's inheritance reference. A page does not really
need a project to be set...
= Index node
By default, node with id=1 is the 'root' of all other nodes. It's the only node in Zena without a reference (no parent and no
project). Some special rules apply to this node : TODO...
=end
class Node < ActiveRecord::Base
  has_many           :discussions
  validate_on_create :node_on_create
  validate_on_update :node_on_update
  after_save         :spread_project_id
  before_destroy     :node_on_destroy
  acts_as_secure
  acts_as_multiversioned
  link :tags, :class_name=>'Tag'
  link :icon, :class_name=>'Image', :unique=>true
  link :hot_for, :as=>'hot',   :class_name=>'Project', :as_unique=>true
  link :home_for, :as=>'home', :class_name=>'Project', :as_unique=>true
  
  class << self
    # valid parent class
    def parent_class
      Node
    end
    
    # Find an node by it's full path. Cache 'fullpath' if found.
    def find_by_path(path)
      node = self.find_by_fullpath(path)
      if node.nil?
        path = path.split('/')
        last = path.pop
        Node.with_exclusive_scope do
          node = Node.find(ZENA_ENV[:root_id])
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
  end
  
  # return the list of ancestors (without self): [root, obj, obj]
  # ancestors to which the visitor has no access are removed from the list
  def ancestors
    if self[:id] == ZENA_ENV[:root_id]
      []
    elsif parent = Node.find_by_id(self[:parent_id])
      parent.set_visitor(visitor_id, visitor_groups, visitor_lang)
      if parent.can_read?
        parent.ancestors + [parent]
      else
        parent.ancestors
      end
    else
      []
    end
  end
  
  # url base path. cached. If rebuild is set to true, the cache is updated.
  def basepath(rebuild=false)
    if self[:custom_base]
      fullpath
    elsif !rebuild && self[:basepath]
      self[:basepath]
    else
      if self[:parent_id]
        Node.with_exclusive_scope do
          parent = Node.find_by_id(self[:parent_id])
        end
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
      if parent
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

  # Make sure the node is complete before creating it (check parent and project references)
  def node_on_create
    # make sure project is the same as the parent
    if self.kind_of?(Project)
      self[:project_id] = nil
    else
      self[:project_id] = parent[:project_id]
    end
    # make sure parent is not a 'Note'
    errors.add("parent_id", "invalid parent") unless parent.kind_of?(self.class.parent_class) || (self[:id] == ZENA_ENV[:root_id] && self[:parent_id] == nil)
    # set name from title if name not set yet
    self.name = version[:title] unless self[:name]
    errors.add("name", "can't be blank") unless self[:name] and self[:name] != ""
    
    # we are in a scope, we cannot just use the normal validates_... (+ it is done before this validation, which is bad as we set 'name' here...)
    test_same_name = nil
    Node.with_exclusive_scope do
      test_same_name = Node.find(:all, :conditions=>["name = ? AND parent_id = ?", self[:name], self[:parent_id]])
    end
    errors.add("name", "has already been taken") unless test_same_name == []
    errors.add("version", "can't be blank") unless @version
  end

  # Make sure parent and project references are valid on update
  def node_on_update
    # make sure project is the same as the parent
    if self.kind_of?(Project)
      self[:project_id] = self[:id]
    else
      self[:project_id] = parent[:project_id]
    end
    
    if self[:project_id] != old[:project_id]
      @spread_project_id = true
    end
    
    if self[:id] == ZENA_ENV[:root_id]
      errors.add('parent_id', 'parent must be empty for root') unless self[:parent_id].nil?
    end
    
    # make sure parent is valid
    errors.add("parent_id", "invalid parent") unless parent.kind_of?(self.class.parent_class) || (self[:id] == ZENA_ENV[:root_id] && self[:parent_id] == nil)
    
    self.name = version[:title] unless self[:name]
    errors.add("name", "can't be blank") unless self[:name] and self[:name] != ""
    
    test_same_name = nil
    Node.with_exclusive_scope do
      test_same_name = Node.find(:all, :conditions=>["name = ? AND id != ? AND parent_id = ?", self[:name], self[:id], self[:parent_id]])
    end
    errors.add("name", "has already been taken") unless test_same_name == []
    # remove cached fullpath
    self[:fullpath] = nil
  end
  
  # after node is saved, make sure it's children have the correct project set
  def spread_project_id
    if @spread_project_id
      # update children
      sync_project(project_id)
      remove_instance_variable :@spread_project_id
    end
  end
  
  # Called before destroy. An node must be empty to be destroyed
  def node_on_destroy
    unless all_children.size == 0
      errors.add('base', "contains subpages")
      return false
    else
      return true
    end
  end
  
  def relation_methods
    ['root', 'project', 'parent', 'self', 'children', 'pages', 'documents', 'documents_only', 'images', 'notes']
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

  def root(opts={})
    secure(Node) { Node.find(ZENA_ENV[:root_id])}
  rescue ActiveRecord::RecordNotFound
    nil
  end
  
  # Find all children
  def children(opts={})
    @children ||= secure(Node) { Node.find(:all, relation_options(opts)) }
  end
  
  def notes
    nil
  end
  
  # Find parent
  def parent
    secure(Node) { Node.find(self[:parent_id]) }
  rescue ActiveRecord::RecordNotFound
    nil
  end
  
  # Find project
  def project
    secure(Project) { Project.find(self[:project_id]) }
  rescue ActiveRecord::RecordNotFound
    nil
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

  # Create a child and let him inherit from rwp groups and project_id
  def new_child(opts={})
    c = Node.new(opts)
    c.parent_id  = self[:id]
    c.set_visitor(visitor_id, visitor_groups, visitor_lang)
    c.pgroup_id  = self.pgroup_id
    c.rgroup_id  = self.rgroup_id
    c.wgroup_id  = self.wgroup_id
    c.project_id = self.project_id
    c.inherit = 1
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
  
  # transform an Node into another Object. This is a two step operation :
  # 1. create a new object with the attributes from the old one
  # 2. move old object out of the way (setting parent_id and project_id to -1)
  # 3. try to save new object
  # 4. delete old and set new object id to old
  # THIS IS DANGEROUS !! NEEDS TESTING
  def change_to(klass)
    return nil if self[:id] == ZENA_ENV[:root_id]
    # FIXME: check for class specific information (file to remove, participations, tags, etc) ... should we leave these things and
    # not care ?
    # FIXME: when changing into something else : update version type and data !!!
    my_id = self[:id].to_i
    my_parent = self[:parent_id].to_i
    my_project = self[:project_id].to_i
    connection = self.class.connection
    # 1. create a new object with the attributes from the old one
    new_obj = secure(klass) { klass.new(self.attributes) }
    # 2. move old object out of the way (setting parent_id and project_id to -1)
    self.class.connection.execute "UPDATE #{self.class.table_name} SET parent_id='0', project_id='0' WHERE id=#{my_id}"
    # 3. try to save new object
    if new_obj.save
      tmp_id = new_obj[:id]
      # 4. delete old and set new object id to old. Delete tmp Version.
      self.class.connection.execute "DELETE FROM #{self.class.table_name} WHERE id=#{my_id}"
      self.class.connection.execute "DELETE FROM #{Version.table_name} WHERE node_id=#{tmp_id}"
      self.class.connection.execute "UPDATE #{self.class.table_name} SET id='#{my_id}' WHERE id=#{tmp_id}"
      self.class.connection.execute "UPDATE #{self.class.table_name} SET project_id=id WHERE id=#{my_id}" if new_obj.kind_of?(Project)
      self.class.logger.info "[#{self[:id]}] #{self.class} --> #{klass}"
      if new_obj.kind_of?(Project)
        # update project_id for children
        sync_project(my_id)
      elsif self.kind_of?(Project)
        # update project_id for children
        sync_project(parent[:project_id])
      end
      secure ( klass ) { klass.find(my_id) }
    else
      # set object back
      self.class.connection.execute "UPDATE #{self.class.table_name} SET parent_id='#{my_parent}', project_id='#{my_project}' WHERE id=#{my_id}"
      self
    end
  end

  # Find the discussion for the current context (v_status and v_lang)
  def discussion
    @discussion ||= Discussion.find(:first, :conditions=>[ "node_id = ? AND inside = ? AND lang = ?", 
                    self[:id], v_status != Zena::Status[:pub], v_lang ]) ||
          if ZENA_ENV[:pub_comments] || ( v_status != Zena::Status[:pub] ) ||
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
  def can_comment?
    discussion && ((discussion.open? && (visitor_id != 1 || ZENA_ENV[:allow_anonymous_comments])) || visitor_id == 2)
  end
  
  # Add a comment to an node. If reply_to is set, the comment is added to the proper message
  # TODO: test
  def add_comment(opt)
    return nil unless can_comment?
    discussion.save if discussion.new_record?
    author = opt[:author_name] = nil unless visitor_id == 1
    opt.merge!( :discussion_id=>discussion[:id], :user_id=>visitor_id )
    Comment.create(opt)
  end
  
  # TODO: test
  def sweep_cache
    return unless Cache.perform_caching
    [self, self.project, self.parent].compact.uniq.each do |obj|
      ZENA_ENV[:languages].each do |lang|
        filepath = File.join(RAILS_ROOT,'public',lang,obj.fullpath)
        filepath = "#{filepath}.html"
        if File.exist?(filepath)
          File.delete(filepath)
        end
      end
    end
  end
  
  protected
  
  def sync_project(project_id)
    all_children.each do |child|
      next if child.kind_of?(Project)
      child[:project_id] = project_id
      child.save_with_validation(false)
      child.sync_project(project_id)
    end
  end
  
  private
      
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
    documents = secure_drive(Document) { Document.find(:all, :conditions=>"parent_id = #{self[:id]}") }
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
    Cache.sweep(:visitor_id=>self[:user_id], :visitor_groups=>[rgroup_id, wgroup_id, pgroup_id], :kpath=>self.class.kpath)
    sweep_cache
    true
  end
  
  # Find all children, whatever visitor is here (used to check if the node can be destroyed or to update project)
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
  def ref_field
    if self[:id] == ZENA_ENV[:root_id]
      :id # root is it's own reference
    else
      :parent_id
    end
  end
end
