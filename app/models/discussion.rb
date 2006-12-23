class Discussion < ActiveRecord::Base
  has_many :all_comments, :class_name=>'Comment', :foreign_key=>'discussion_id', :order=>'created_at ASC', :dependent=>:delete_all
  belongs_to :item
  
  # An open discussion means new comments can be added
  def open?; self[:open]; end
  
  # An +inside+ discussion is not visible when the version is published.
  # Item readers = discussion readers = commentators
  def inside?; self[:inside]; end
  
  def can_destroy?
    all_comments.size == 0
  end
  
  def comments(opt={})
    if opt[:with_prop]
      conditions = ["discussion_id = ? AND reply_to IS NULL AND status > #{Zena::Status[:rem]}", self[:id]]
    else
      conditions = ["discussion_id = ? AND reply_to IS NULL AND status = #{Zena::Status[:pub]}", self[:id]]
    end
    Comment.find(:all, :conditions=>conditions, :order=>'created_at ASC')
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
end
