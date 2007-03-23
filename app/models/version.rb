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

comment:: The comment is a little word saying what this particular version is about or a full text on all the modifications done or to be done or anything usefull that should be communicated inside the team.
text:: The text is the full content of a version. The text usually contains zazen formatted text (textile with additions). See Zazen for details.

== Content
If a we need to create a more sophisticated version class, all the required fields go in a 'content' class, like 
#DocumentContent stores document type and size for #DocumentVersion. See #Document for the details on the relation between Version and Content.
=end
class Version < ActiveRecord::Base
  belongs_to            :node
  belongs_to            :user, :foreign_key=>'user_id' # FIXME: can we remove this
  before_validation     :version_before_validation
  validates_presence_of :node
  validates_presence_of :user
  validate              :valid_version
  validate_on_update    :can_update_content
  after_save            :save_content
  
  # not tested belongs_to :comment_group, :class_name=>'Group', :foreign_key=>'cgroup_id'
  # not tested has_many :comments, :order=>'created_at'
  
  # Author is an alias for user
  def author
    user
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
    return @content if @content
    if self[:content_id]
      @content = content_class.find_by_version_id(self[:content_id])
    else
      @content = content_class.find_by_version_id(self[:id])
    end
    unless @content
      # create new content
      @content = content_class.new
      self[:content_id] = nil
      @redaction_content = @content
      @content.version = self
    end
    @content
  end
  
  # Return the version's own content or creates a new one so it can be edited.
  def redaction_content
    return @redaction_content if @redaction_content
    return unless content_class
    @content = content
    if @content && @content[:version_id] == self[:id]
      # own content, nothing to do
    elsif @content
      # content shared, make it our own
      @old_content = @content # keep the old own in case we cannot save and need to rollback
      @content = @content.clone
      @content.version = self
      self[:content_id] = nil
    else
      # create new content
      @content = content_class.new
      @content.version = self
      self[:content_id] = nil
    end  
    @redaction_content = @content
  end
  
  private
  
  def can_update_content
    if @redaction_content && Version.find_all_by_content_id(self[:id]).size > 0
      # some versions link to this version's content directly. Cannot change content.
      errors.add('base', 'cannot change content (used by other versions)')
    end
  end
  
  def save_content
    if @content
      @content.save_without_validation # validations checked with 'valid_content'
    else
      true
    end
  end
  
  # Set version number and site_id before validation tests.
  def version_before_validation
    return unless node
    self[:site_id] = node[:site_id]
    if new_record?
      last = Version.find(:first, :conditions=>['node_id = ?', node[:id]], :order=>'number DESC')
      self[:type] = self.class.to_s
      if last
        self[:number] = last[:number] + 1
      else
        self[:number] = 1
      end
    end
    if content_class
      content[:name]    = node[:name]
      content[:site_id] = self[:site_id]
    end
  end
  
  # Make sure the version and it's related content are in a correct state.
  def valid_version
    errors.add("site_id", "can't be blank") unless self[:site_id] and self[:site_id] != ""
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
      return false
    end
  end
  
  # Some #Version sub-classes need to have more specific content than just 'text' and 'summary'.
  # this content is stored in a delegate 'content' object found with the 'content_class' class method
  def content_class
    nil
  end
end
