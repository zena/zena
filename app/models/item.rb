=begin rdoc
An Item is the parent for all web content classes (#Page, #Event, #Log, #Document, #Category, #Project).

== #Note vs #Page vs #Documents
A #Note is something related to *time* for a certain #Project. A #Page is some structured data organised as a tree.
A note's parent can only be a Project. A page's parent can be any kind of #Page. There is a special case for documents. A #Document
can have a #Note as parent and it cannot have children.

== Secure access
See #Zena::Acts::Secure

== Editions vs Versions
An edition is a _published_ version. An item can only have one edition per language. If there is no edition
available in the current language the +ref_lang+ edition is shown instead. If the latter does not exist any
edition is shown.

If an item does not have any editions : it <i>does not exist</i>. It will appear nowhere. Only it's current versions
will show up as <i>working copies</i> on the user's home page.

Changing versions (rollback, rollforward) is done by first choosing 'manage' action. This action shows a list of versions for 
the current language (in item_actions). There should be a possibility to change lang or show all. Each line has 'show' 
(live_preview). Once the version is shown: 'rollxxx', 'show_diff'.

Here is a drawing of version status :
link://../img/zena_versions_life.png

= Item life cycle

== New
link://../img/zena_new_item.png

== Publication
There can only be one published version per language. The published_at date is set to some datetime in the future or
simply to +now+. The publication date cannot be set to a moment in the past (it should only be used to make the item appear
on the site at a specified date). This ensures that we can see how the site was, somewhere in the past.

Setting a #Version from +red+ to +prop+ proposes to change all children (status=red, same owner) to 'prop'.
Publishing a #Version proposes to publish all children (status=prop, same owner).

== Display
When an item is displayed, it shows it's edition and some other element :
[contact] If the item is a presentation page for a contact : display contact partial
[document] If the item is a #Document : display preview and link for download.
[book] Display a book reference if there is one.
[action] Depending on user rights, display buttons to 'edit, add, remove' item.

= Relation to project
This part is not very clear yet. A Note must have a project as this is it's inheritance reference. A page does not really
need a project to be set...
= Index item
By default, item with id=1 is the 'root' of all other items. It's the only item in Zena without a reference (no parent and no
project). Some special rules apply to this item : TODO...
=end
class Item < ActiveRecord::Base
  has_many           :discussions
  validate_on_create :item_on_create
  validate_on_update :item_on_update
  after_save         :spread_project_id
  before_destroy     :item_on_destroy
  acts_as_secure
  acts_as_multiversioned
  link :tags, :class_name=>'Tag'
  link :hot_for, :as=>'hot', :class_name=>'Project', :as_unique=>true
  
  class << self
    # valid parent class
    def parent_class
      Item
    end
    
    # Find an item by it's full path. Cache 'fullpath' if found.
    def find_by_path(visitor_id, visitor_groups, lang, path)
      item = Item.find_by_fullpath(path.join('/'))
      unless item
        raise ActiveRecord::RecordNotFound unless item = Item.find(ZENA_ENV[:root_id])
        path.each do |p|
          raise ActiveRecord::RecordNotFound unless item = Item.find_by_name_and_parent_id(p, item[:id])
        end
        item.fullpath = path.join('/')
        # bypass callbacks here
        Item.connection.execute "UPDATE #{Item.table_name} SET fullpath='#{path.join('/').gsub("'",'"')}' WHERE id='#{item[:id]}'"
      end
      if item.can_read?(visitor_id, visitor_groups)
        item.set_visitor(visitor_id, visitor_groups, lang)
      else
        raise ActiveRecord::RecordNotFound
      end
    end
  end

  # Return the full path as an array if it is cached or build it when asked for.
  def fullpath
    if self[:fullpath]
      self[:fullpath].split('/')
    else
      if parent
        f = parent.fullpath << name
      else
        f = []
      end
      self.connection.execute "UPDATE #{self.class.table_name} SET fullpath='#{f.join('/')}' WHERE id='#{self[:id]}'"
      f
    end
  end
  
  # Same as fullpath, but the path includes the root item.
  def rootpath
    [ZENA_ENV[:site_name]] + fullpath
  end

  # Make sure the item is complete before creating it (check parent and project references)
  def item_on_create
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
    Item.with_exclusive_scope do
      test_same_name = Item.find(:all, :conditions=>["name = ? AND parent_id = ?", self[:name], self[:parent_id]])
    end
    errors.add("name", "has already been taken") unless test_same_name == []
    errors.add("version", "can't be blank") unless @version
  end

  # Make sure parent and project references are valid on update
  def item_on_update
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
    Item.with_exclusive_scope do
      test_same_name = Item.find(:all, :conditions=>["name = ? AND id != ? AND parent_id = ?", self[:name], self[:id], self[:parent_id]])
    end
    errors.add("name", "has already been taken") unless test_same_name == []
    # remove cached fullpath
    self[:fullpath] = nil
  end
  
  # after item is saved, make sure it's children have the correct project set
  def spread_project_id
    if @spread_project_id
      # update children
      sync_project(project_id)
      remove_instance_variable :@spread_project_id
    end
  end
  
  # Called before destroy. An item must be empty to be destroyed
  def item_on_destroy
    unless all_children.size == 0
      errors.add('base', "contains subpages")
      return false
    else
      return true
    end
  end
  
  # Find all children
  def children
    @children ||= secure(Item) { Item.find(:all, :conditions=>['parent_id = ?', self[:id] ]) }
  end
  
  # Find parent
  def parent
    secure(Item) { Item.find(self[:parent_id]) }
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
  def pages
    @pages ||= secure(Page) { 
      Page.find(:all, :order=>'name ASC', :conditions=>["parent_id = ? AND kpath NOT LIKE 'IPD%'", self[:id] ]) }
  end
  
  # Find documents
  def documents
    @documents ||= secure(Document) { Document.find(:all, :order=>'name ASC', :conditions=>['parent_id=?', self[:id]] ) }
  end

  # Find documents without images
  def documents_only
    @doconly ||= secure(Document) { Document.find(:all, :order=>'name ASC', :conditions=>["parent_id=? AND kpath NOT LIKE 'IPDI%'", self[:id]] ) }
  end
  
  # Find only images
  def images
    @images ||= secure(Image) { Image.find(:all, :order=>'name ASC', :conditions=>['parent_id=?', self[:id]] ) }
  end
  
  # Find only notes
  def notes
    @notes ||= secure(Note) { Note.find(:all, :order=>'name ASC', :conditions=>['parent_id=?', self[:id]] ) }
  end
 
  # Find all trackers
  def trackers
    @trackers ||= secure(Tracker) { Tracker.find(:all, :order=>'name ASC', :conditions=>['parent_id=?', self[:id]] ) }
  end

  # Create a child and let him inherit from rwp groups and project_id
  def new_child(opts={})
    c = Item.new(opts)
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
  
  # TODO:test
  def summary
    if v_summary != ''
      v_summary
    else
      txt = v_text.gsub("\n",' ').gsub("\r",' ')
      if txt.size > 100
        txt.limit(100)
      else
        txt
      end
    end
  end
  
  def ext
    (name && name != '' && name =~ /\./ ) ? name.split('.').last : ''
  end
    
  # set name: remove all accents and camelize
  def name=(str)
    return unless str && str != ""
    self[:name] = camelize(str)
  end
  
  # transform an Item into another Object. This is a two step operation :
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
      self.class.connection.execute "DELETE FROM #{Version.table_name} WHERE item_id=#{tmp_id}"
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
    @discussion ||= Discussion.find(:first, :conditions=>[ "item_id = ? AND inside = ? AND lang = ?", 
                    self[:id], v_status != Zena::Status[:pub], v_lang ]) ||
          if ( v_status != Zena::Status[:pub] ) ||
             ( Discussion.find(:first, :conditions=>[ "item_id = ? AND inside = ? AND open = ?", 
                                     self[:id], false, true ]))
            # v_status is not :pub or we already have an outside, open discussion for this item             
            # => we can create a new one
            Discussion.new(:item_id=>self[:id], :lang=>v_lang, :inside=>(v_status != Zena::Status[:pub]))
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
  
  # Return true if it is allowed to add comments to the item in the current context
  def can_comment?
    discussion && (discussion.open? || visitor_id == 2)
  end
  
  # Add a comment to an item. If reply_to is set, the comment is added to the proper message
  # TODO: test
  def add_comment(opt)
    return nil unless can_comment?
    discussion.save if discussion.new_record?
    author = opt[:author_name] = nil unless visitor_id == 1
    opt.merge!( :discussion_id=>discussion[:id], :user_id=>visitor_id )
    Comment.create(opt)
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
      
  # Called after an item is 'removed'
  def after_remove
    if self[:max_status] < Zena::Status[:pub]
      # not published any more. 'remove' documents
      sync_documents(:remove)
    else
      true
    end
  end
  
  # Called after an item is 'proposed'
  def after_propose
    sync_documents(:propose)
  end
  
  # Called after an item is 'refused'
  def after_refuse
    sync_documents(:refuse)
  end
  
  # Called after an item is published
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
      # FIXME: use a 'before_remove' callback to make sure all sub-items can be removed...
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
  
  # Whenever something changed (publication/proposition/redaction/...)
  def after_all
    Cache.sweep(:visitor_id=>self[:user_id], :visitor_groups=>[rgroup_id, wgroup_id, pgroup_id], :kpath=>self.class.kpath)
    true
  end
  
  # Find all children, whatever visitor is here (used to check if the item can be destroyed or to update project)
  def all_children
    Item.with_exclusive_scope do
      Item.find(:all, :conditions=>['parent_id = ?', self[:id] ])
    end
  end
  
  def camelize(str)
    accents = { ['á','à','â','ä','ã','Ã','Ä','Â','À'] => 'a',
      ['é','è','ê','ë','Ë','É','È','Ê'] => 'e',
      ['í','ì','î','ï','I','Î','Ì'] => 'i',
      ['ó','ò','ô','ö','õ','Õ','Ö','Ô','Ò'] => 'o',
      ['œ'] => 'oe',
      ['ß'] => 'ss',
      ['ú','ù','û','ü','U','Û','Ù'] => 'u'
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
    Item
  end
  
  # Reference class
  def ref_class
    Item
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