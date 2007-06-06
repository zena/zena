=begin rdoc
A version implements versioning and permits multiple publications (one for each language).

=== Status

A version's status changes over time. A version usually starts by being a 'redaction', these eventually a 'proposition', etc. The version's status changes by executing actions on the node (publish, remove, etc). Have a look at Acts::As::Multiversion for details. Zena::Status are :

pub (50)::  version is published (can be seen by all readers)
prop (40):: proposed for publication (seen only by the members of the publish group of the node)
prop_with (35):: document proposed with the redaction. Will be automatically published/removed with the redaction.
red (30):: version is being written (the redaction is only seen by its author)
rep (20):: replaced by a newer version (can be an elligible version for rollback)
rem (10):: removed (from a rollback)
del (0):: this is like 'moved to trash'

=== Version attributes

title:: Node title.
comment:: The comment is a little word saying what this particular version is about or a full text on all the modifications done or to be done or anything usefull that should be communicated inside the team.
text:: The text is the full content of a version. The text usually contains zazen formatted text (textile with additions). See Zazen for details.

=== Dynamic attributes

Any attribute written using version.dyn[:blah] = 'some text' is stored as a dynamic attribute. See DynAttributes for details.

== Content
If a we need to create a more sophisticated version class, all the required fields go in a 'content' class, like 
#DocumentContent stores document type and size for #DocumentVersion. See #Document for the details on the relation between Version and Content.
=end
class Version < ActiveRecord::Base

  zafu_readable      :title, :text, :summary, :created_at, :updated_at, :publish_from, :status, 
                     :wgroup_id, :pgroup_id, :zip, :lang, :user_zip
  
  belongs_to            :node
  belongs_to            :user
  before_validation     :version_before_validation
  validates_presence_of :user
  validate              :valid_version
  after_save            :save_content
  after_destroy         :destroy_content
  before_create         :set_number
  uses_dynamic_attributes
  
  class << self
    # Some #Version sub-classes need to have more specific content than just 'text' and 'summary'.
    # this content is stored in a delegate 'content' object found with the 'content_class' class method
    def content_class
      nil
    end
  end
  
  def author
    user.contact
  end
  
  alias o_node node
  
  def node
    @node ||= secure(Node) { o_node } rescue nil
  end
  
  def user_zip
    user_id
  end
  
  def zip
    "#{node.zip}.#{number}"
  end
  
  # Return the title or the node's name if the field is empty.
  def title
    if self[:title] && self[:title] != ""
      self[:title]
    else
      node.name
    end
  end
  
  # protect access to node_id : should not be changed by users
  def node_id=(i)
    raise Zena::AccessViolation, "Version '#{self.id}': tried to change 'node_id' to '#{i}'."
  end
  
  # protect access to content_id
  def content_id=(i)
    raise Zena::AccessViolation, "Version '#{self.id}': tried to change 'content_id' to '#{i}'."
  end
  
  # Return the content for the version. Can it's 'own' content or the same as the version this one was copied from.
  def content
    return nil unless content_class
    return @content if @content
    if self[:content_id]
      @content = content_class.find_by_version_id(self[:content_id])
    else
      @content = content_class.find_by_version_id(self[:id])
      @content.version = self if @content
    end
    unless @content
      # create new content
      @content = content_class.new
      self[:content_id] = nil
      @content.version = self
      @redaction_content = @content
    end    
    @content
  end
  
  # Return the version's own content or creates a new one so it can be edited.
  def redaction_content
    return @redaction_content if @redaction_content
    return unless content_class
    @content = content
    if @content && @content[:version_id] == self[:id]
      # own content, make sure no published version links to this content
      if !new_record? && Version.find(:first, :select=>'id', :conditions=>["content_id = ?",self[:id]])
        errors.add('content', 'cannot be changed')
        return nil
      end
    elsif @content
      # content shared, make it our own
      @old_content = @content # keep the old one in case we cannot save and need to rollback
      @content = @old_content.clone
      self[:content_id] = nil
      @content.version = self
    else
      # create new content
      @content = content_class.new
      self[:content_id] = nil
      @content.version = self
    end
    @redaction_content = @content
  end
  
  def clone
    obj = super
    # clone dynamic attributes
    obj.dyn = self.dyn
    obj
  end
  
  def content_class
    self.class.content_class
  end
  
  private
    def set_number
      last_record = node[:id] ? self.connection.select_one("select number from #{self.class.table_name} where node_id = '#{node[:id]}' ORDER BY number DESC LIMIT 1") : nil
      self[:number] = (last_record || {})['number'].to_i + 1
    end
    
    def save_content
      if @content
        @content.save_without_validation # validations checked with 'valid_content'
      else
        true
      end
    end
    
    def destroy_content
      content.destroy if content_class && content.can_destroy?
    end
  
    # Set version number and site_id before validation tests.
    def version_before_validation
      unless node
        errors.add('base', 'node missing')
        return false
      end
      self[:site_id] = node[:site_id]
    
      # [ why do we need these defaults now ? (since rails 1.2)
      self[:text]    ||= ""
      self[:title]   ||= node[:name]
      self[:summary] ||= ""
      self[:comment] ||= ""
      self[:type]    ||= self.class.to_s
      # ]
      self[:lang] = visitor.lang if self[:lang].blank?
      if @content
        @content[:site_id] = self[:site_id]
      end
    end
  
    # Make sure the version and it's related content are in a correct state.
    def valid_version
      errors.add("site_id", "can't be blank") unless self[:site_id] and self[:site_id] != ""
      errors.add('lang', 'not valid') unless visitor.site.lang_list.include?(self[:lang])
      # validate content
      if @content && !@content.valid?
        @content.errors.each do |key,message|
          if key.to_s == 'base'
            errors.add(key.to_s,message)
          else
            errors.add("c_#{key}",message)
          end
        end
      
        if @old_content
          @content = @old_content # rollback initial content
        else
          # clean empty content
          @content = content_class.new
          @content.version = self
          self[:content_id] = nil
          @redaction_content = @content
        end
      end
    end
end
