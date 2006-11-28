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
=end
class Version < ActiveRecord::Base
  belongs_to :item
  belongs_to :user, :foreign_key=>'user_id'
  validates_presence_of :item
  validates_presence_of :user
  validate    :validate_content
  before_save Proc.new { if @content then @content.save else true end }
  before_create :set_number
  
  # not tested belongs_to :comment_group, :class_name=>'Group', :foreign_key=>'cgroup_id'
  # not tested has_many :comments, :order=>'created_at'
  
  # Author is an alias for user
  def author
    user
  end
  
  # protect access to item_id and file_ref : should not be changed by users
  def item_id=(i)
    raise Zena::AccessViolation, "Version #{self.id}: tried to change 'item_id' to '#{i}'."
  end
  
  def content
    @content ||= if self[:shown_content_id]
      content_class.find(self[:shown_content_id])
    elsif self[:content_id]
      content_class.find(self[:content_id])
    else
      nil
    end
  end
  
  private
  
  # Set version number
  def set_number
    last = Version.find(:first, :conditions=>['item_id = ?', item[:id]], :order=>'number DESC')
    if last
      self[:number] = last[:number] + 1
    else
      self[:number] = 1
    end
  end
  
  # Validate content validity callback
  def validate_content
    if @content && !@content.valid?
      @content.errors.each do |key,message|
        errors.add(key,message)
      end
    end
  end
    
  # pass calls starting with 'c_' to content
  def method_missing(meth, *args)
    if meth.to_s =~ /^c_(.+)$/
      content.send($1.to_sym, *args)
    else
      super
    end
  end
  
  # Some #Version sub-classes need to have more specific content than just 'text' and 'summary'.
  # this content is stored in a delegate 'content' object found with the 'content_class' class method
  def content_class
    nil
  end
end
