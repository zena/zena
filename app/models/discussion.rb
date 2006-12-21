class Discussion < ActiveRecord::Base
  has_many :comments, :conditions=>"reply_to IS NULL AND status = '#{Zena::Status[:pub]}'", :order=>'created_at ASC'
  has_many :all_comments, :class_name=>'Comment', :foreign_key=>'discussion_id', :order=>'created_at ASC', :dependent=>:delete_all
  
  # An open discussion means new comments can be added
  def open?; self[:open]; end
  
  # An +inside+ discussion is not visible when the version is published.
  # Item readers = discussion readers = commentators
  def inside?; self[:inside]; end
  
  def can_destroy?
    all_comments.size == 0
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
