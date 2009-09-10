=begin rdoc
A #Discussion holds a list of comments for a #Node. An +inside+ discussion only appears when the
node is not published. A #Comment can be added to an +open+ discussion. Discussions only show in
there current language (each traduction gets its own discussion). #Discussions can be created in
the 'drive' popup or are automatically created when the first comment is added. Discussions are
automatically created only if there already exists an +outside+ and +open+ discussion for another
language and if the current visitor is a commentator (User.commentator?). 
=end
class Discussion < ActiveRecord::Base
  
  attr_protected :site_id
  has_many :all_comments, :class_name=>'Comment', :foreign_key=>'discussion_id', :order=>'created_at ASC', :dependent=>:delete_all
  belongs_to :node
  before_validation :discussion_before_validation
  
  # An open discussion means new comments can be added
  def open?; self[:open]; end
  
  # An +inside+ discussion is not visible when the version is published.
  # Node readers = discussion readers = commentators
  def inside?; self[:inside]; end
  
  def can_destroy?
    all_comments.size == 0
  end
  
  def comments(opts={})
    if opts[:with_prop]
      conditions = ["discussion_id = ? AND reply_to IS NULL AND status > #{Zena::Status[:rem]}", self[:id]]
    else
      conditions = ["discussion_id = ? AND reply_to IS NULL AND status = #{Zena::Status[:pub]}", self[:id]]
    end
    Comment.find(:all, :conditions=>conditions, :order=>'created_at ASC')
  end
  
  def comments_count(opts={})
    if opts[:with_prop]
      conditions = ["discussion_id = ? AND status > #{Zena::Status[:rem]}", self[:id]]
    else
      conditions = ["discussion_id = ? AND status = #{Zena::Status[:pub]}", self[:id]]
    end
    Comment.count(:all, :conditions=>conditions)
  end
  
  # TODO: test
  def destroy
    if can_destroy?
      super
    else
      errors.add('comments', 'not empty')
      false
    end
  end
  
  alias o_node node
  
  def node
    secure!(Node) { o_node }
  end
  
  private
    def discussion_before_validation
      self[:site_id] = node.site_id
    end
end
