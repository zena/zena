=begin rdoc
Implements versioning and permits multiple editions on items.

== Attributes and definitions
[edition] an edition is a published version for a specific language. There can only be on edition per language per item.
[status] can be
         [pub] version is published
         [prop] proposed for publication
         [red] version is being written (redaction)
         [rep] replaced by a newer version (can be an elligible version for rollback)
         [rem] removed (from a rollback)
         [del] this is like 'moved to trash'
[comment] The comment is a little word saying what this particular version is about or a full text on all
          the modifications done or to be done or anything usefull (it is normally to published).
[text] The text is the full content of a version. This method returns the text as a
       RedCloth object. Use ApplicationHelper#h method to render with zena additions to Textile.
[summary] The summary is a brief presentation. Its main purpose is to give some clues on an item in a list view.
[comment_group] This is the group users must be in if they want to add comments to this version/edition. If this
                group is set to _public_ anyone can comment.
[doc_path] path to file containing the data if this is a version of a document.
[doc_preview] optional image preview of the document

== Content
If a we need to create a more sophisticated version class, all the required fields go in a 'content' class, like 
#DocumentContent stores document type and size for #DocumentVersion. In some cases, the text in a version is translated but the 
content in the 'content' record must stay the same (for example, you can translate the comment on an image but the image s
tays the same). In this case, the new #Version's content is linked through : version.content_id-->content.version_id.
Thus the field 'content_id' means 'use content from version x'. As soon as we edit the content from a version using another's
content, we create our own copy to work on. In some rare cases where we publish a version and then we edit it again (without creating
a new redaction), the system will not allow us to save the modified content as it is used by other (potentially published) versions.
=end
class Version < ActiveRecord::Base
  belongs_to            :item
  belongs_to            :user, :foreign_key=>'user_id'
  validates_presence_of :item
  validates_presence_of :user
  validate              :valid_content
  validate_on_update    :can_update_content
  after_save            :save_content
  before_create         :set_number
  
  # not tested belongs_to :comment_group, :class_name=>'Group', :foreign_key=>'cgroup_id'
  # not tested has_many :comments, :order=>'created_at'
  
  # Author is an alias for user
  def author
    user
  end
  
  def title
    if self[:title] && self[:title] != ""
      self[:title]
    else
      item.name
    end
  end
  
  # protect access to item_id and conten_id : should not be changed by users
  def item_id=(i)
    raise Zena::AccessViolation, "Version '#{self.id}': tried to change 'item_id' to '#{i}'."
  end
  
  # protect access to content_id
  def content_id=(i)
    raise Zena::AccessViolation, "Version '#{self.id}': tried to change 'conten_id' to '#{i}'."
  end
    
  def content
    return @content if @content
    if self[:content_id]
      @content = content_class.find_by_version_id(self[:content_id])
    else
      content_class.find_by_version_id(self[:id])
    end
  end
  
  # called by 'multiversion' when we need a new redaction for a version
  def redaction_content
    return @redaction_content if @redaction_content
    return unless content_class
    @content = content
    if @content && @content.version == self
      @redaction_content = @content
    elsif @content
      @content = content.clone
      @content.version = self
      self[:content_id] = self[:id]
      @redaction_content = @content
    else
      @content = content_class.new
      @content.version = self
      self[:content_id] = nil
      @redaction_content = @content
    end
  end

  private
  
  def can_update_content
    if Version.find_all_by_content_id(self[:id]).size > 0
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
  
  # Set version number
  def set_number
    last = Version.find(:first, :conditions=>['item_id = ?', item[:id]], :order=>'number DESC')
    if last
      self[:number] = last[:number] + 1
    else
      self[:number] = 1
    end
  end
  
  def valid_content
    if @content && !@content.valid?
      @content.errors.each do |key,message|
        if key.to_s == 'base'
          errors.add(key.to_s,message)
        else
          errors.add("c_#{key}",message)
        end
      end
    end
  end
  
  # Some #Version sub-classes need to have more specific content than just 'text' and 'summary'.
  # this content is stored in a delegate 'content' object found with the 'content_class' class method
  def content_class
    nil
  end
end
