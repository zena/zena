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
  acts_as_secure
  acts_as_multiversioned
  link :tags, :class=>Collector
  # def self.sanitize_sql(ary)
  #   super
  # end
  
  def validate_on_create
    return unless super
    self.class.logger.info "ITEM CALLBACK ON CREATE"
    # make sure project is the same as the parent
    self[:project_id] = parent[:project_id]
    # make sure parent is not a 'Note'
    errors.add("parent_id", "invalid parent") if parent.kind_of?(Note) and !self.kind_of?(Document)
    # set name from title if name not set yet
    self.name = self.title if !self[:name] && self.title
    errors.add("name", "can't be blank") unless self[:name] and self[:name] != ""
    
    # validates_uniqueness_of :name, :scope => :parent_id
    # we are in a scope, we cannot just use the normal validates_... (+ it is done before this validation, which is bad as we set 'name' here...)
    
    test_same_name = nil
    Item.with_exclusive_scope do
      test_same_name = Item.find(:all, :conditions=>["name = ?", self[:name]])
    end
    errors.add("name", "has already been taken") unless test_same_name == []
  end

  def validate_on_update
    return unless super
    self.class.logger.info "ITEM CALLBACK ON UPDATE"
    # make sure project is the same as the parent
    self[:project_id] = parent[:project_id] if self[:parent_id]
    # make sure parent is not a 'Note'
    errors.add("parent_id", "invalid parent") if parent.kind_of?(Note) and !self.kind_of?(Document)
    
    self.name = self.title unless self[:name]
    errors.add("name", "can't be blank") unless self[:name] and self[:name] != ""
    
    test_same_name = nil
    Item.with_exclusive_scope do
      test_same_name = Item.find(:all, :conditions=>["name = ? AND id != ?", self[:name], self[:id]])
    end
    errors.add("name", "has already been taken") unless test_same_name == []
  end

  def before_destroy
    super
    if errors.empty?
      errors.add('base', "page not empty") unless self.all_children.count == 0
    end
  end
  
  # Find all children
  def children
    @children ||= secure(Item) { all_children } || []
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
      Page.find(:all, :order=>'name ASC', :conditions=>["parent_id = ? AND kpath NOT LIKE 'IPD%'", self[:id] ]) } || []
  end
  
  # Find only documents
  def documents
    @documents ||= secure(Document) { Document.find(:all, :order=>'name ASC', :conditions=>['parent_id=?', self[:id]] ) } || []
  end
  
  # Find only notes
  def notes
    @notes ||= secure(Note) { Note.find(:all, :order=>'name ASC', :conditions=>['parent_id=?', self[:id]] ) } || []
  end
  
  # Find all collectors
  def collectors
    @collectors ||= secure(Collector) { Collector.find(:all, :order=>'name ASC', :conditions=>['parent_id=?', self[:id]] ) } || []
  end
 
  # Find all trackers
  def trackers
    @trackers ||= secure(Tracker) { Tracker.find(:all, :order=>'name ASC', :conditions=>['parent_id=?', self[:id]] ) } || []
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

  # Find an item by it's full path. Cache 'fullpath' if found.
  # TODO: nested scoping works, use it ? See also with_exclusive_scope
  def self.find_by_path(user_id, user_groups, lang, path)
    item = Item.find_by_fullpath(path.join('/'))
    unless item
      raise ActiveRecord::RecordNotFound unless item = Item.find(ZENA_ENV[:root_id])
      path.each do |p|
        raise ActiveRecord::RecordNotFound unless item = Item.find_by_name_and_parent_id(p, item[:id])
      end
      item.fullpath = path.join('/')
      item.save
    end
    if item.can_read?(user_id, user_groups)
      item.set_visitor(user_id, user_groups, lang)
    else
      raise ActiveRecord::RecordNotFound
    end
  end
  
  # Return the full path as an array if it is cached or build it when asked for.
  def fullpath
    if self[:fullpath]
      self[:fullpath].split('/')
    else
      if parent
        f = parent.fullpath << name_for_fullpath
      else
        f = []
      end
      self.connection.execute "UPDATE items SET fullpath='#{f.join('/')}' WHERE items.id='#{self[:id]}'"
      f
    end
  end
  
  # Overwritten by notes
  def name_for_fullpath
    name
  end
  
  # ACCESSORS
  def author
    user
  end
  
  def ext
    name.split('.').last
  end
    
  # set name: remove all accents and camelize
  def name=(str)
    self[:name] = clearName(str)
  end
  
  # TODO: finish list
  
  # transform an Item into another Object. This is a two step operation :
  # 1. create a new object with the attributes from the old one
  # 2. move old object out of the way (setting parent_id and project_id to -1)
  # 3. try to save new object
  # 4. delete old and set new object id to old
  # THIS IS DANGEROUS !! NEEDS TESTING
  #def change_to(klass)
  #  #begin
  #    my_id = self[:id].to_i
  #    my_parent = self[:parent_id].to_i
  #    my_project = self[:project_id].to_i
  #    connection = self.class.connection
  #    # 1. create a new object with the attributes from the old one
  #    new_obj = secure(klass) { klass.new(self.attributes) }
  #    puts new_obj.inspect
  #    # 2. move old object out of the way (setting parent_id and project_id to -1)
  #    connection.execute "UPDATE items SET parent_id='0', project_id='0' WHERE id=#{my_id}"
  #    # 3. try to save new object
  #    if new_obj.save
  #      tmp_id = new_obj[:id]
  #      # 4. delete old and set new object id to old
  #      connection.execute "DELETE items WHERE items.id=#{my_id}"
  #      connection.execute "UPDATE items SET id='#{my_id}' WHERE id=#{tmp_id}"
  #      secure ( klass ) { klass.find(my_id) }
  #    else
  #      puts "ERROR: #{new_obj.show_errors}"
  #      # set object back
  #      connection.execute "UPDATE items SET parent_id='#{my_parent}', project_id='#{my_project}' WHERE items.id=#{my_id}"
  #      self
  #    end
  #  #rescue
  #    # ???
  #  #end
  #end
    
  
  private
  
  # Call backs
  def after_remove
    if self[:max_status] < Zena::Status[:pub]
      sync_children(:remove)
    end
  end
  
  def after_propose
    sync_children(:propose)
  end
  
  def after_refuse
    sync_children(:refuse)
  end
  
  def after_publish(pub_time=nil)
    sync_children(:publish, pub_time)
  end

  # Publish, refuse, propose the Documents of a redaction
  def sync_children(action, pub_time=nil)
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
        if doc.can_publish_item?
          allOK = doc.publish(pub_time) && allOK
        end
      end
    when :remove
      documents.each do |doc|
        allOK = doc.remove && allOK
      end
    end
    allOK
  end

  
  # Find all children, whatever visitor is here (used to check if the item can be destroyed)
  def all_children
    Item.find(:all, :conditions=>['parent_id = ?', self[:id] ])
  end
  
  def clearName(str)
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
