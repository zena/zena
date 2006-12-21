=begin
Comments can be added on a per discussion basis. They can be replies to other comments in the same
discussion. They are signed by the user commenting. Public comments
belong to the user _anon_ (see #User).
=end
class Comment < ActiveRecord::Base
  belongs_to :author, :class_name=>'User', :foreign_key=>'user_id'
  belongs_to :discussion
  has_many   :replies, :class_name=>'Comment', :foreign_key=>'reply_to', :order=>'created_at ASC', :conditions=>"status = '#{Zena::Status[:pub]}'"
  belongs_to :parent, :class_name=>'Comment' , :foreign_key=>'reply_to'
  validates_presence_of :text
  validates_presence_of :title
  before_validation :set_comment
  validate :valid_comment
  
  # TODO: test all above and below !!
  
  # TODO: test
  def remove
    update_attributes( :status=> Zena::Status[:rem])
  end
  
  private
  def set_comment
    if parent && (self[:title].nil? || self[:title] == '')
      self[:title] = TransKey['re:'][discussion.lang] + ' ' + parent.title
    end
    if user_id == 1 && ZENA_ENV[:moderate_public_comments]
      self[:status] = Zena::Status[:prop]
    else
      self[:status] = Zena::Status[:pub]
    end
  end
  
  def valid_comment
    if user_id == 1
      errors.add('author_name', 'cannot be blank') unless author_name && author_name != ''
    else
      self[:author] = nil
    end
  end
end
