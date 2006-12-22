=begin
Comments can be added on a per discussion basis. There can be replies to other comments in the same
discussion. Comments are signed by the user commenting. Public comments
belong to the user _anon_ (see #User) and must have the 'athor_name' field set.

If ZENA_ENV[:moderate_public_comments] is set, all public comments are set to 'prop' and are not directly seen on the site.
=end
class Comment < ActiveRecord::Base
  belongs_to :author, :class_name=>'User', :foreign_key=>'user_id'
  belongs_to :discussion
  has_many   :replies, :class_name=>'Comment', :foreign_key=>'reply_to', :order=>'created_at ASC', :conditions=>"status = '#{Zena::Status[:pub]}'"
  belongs_to :parent,  :class_name=>'Comment', :foreign_key=>'reply_to'
  validates_presence_of :text
  validates_presence_of :title
  validates_presence_of :discussion
  validates_presence_of :author_name, :if => Proc.new {|obj| obj.user_id == 1 }
  before_validation_on_create :set_comment
  
  # Remove the comment (set it's status to +rem+)
  def remove
    self.class.logger.info 'REMOVE ====== ['
    update_attributes( :status=> Zena::Status[:rem] )
    self.class.logger.info '] ====== REMOVE'
  end
  
  private
  def set_comment
    return false unless discussion
    if parent && (self[:title].nil? || self[:title] == '')
      self[:title] = TransKey['re:'][discussion.lang] + ' ' + parent.title
    end
    if user_id == 1 && ZENA_ENV[:moderate_public_comments]
      self[:status] = Zena::Status[:prop]
    else
      self[:status] = Zena::Status[:pub]
    end
    if user_id != 1
      self[:author_name] = nil
    end
  end
end
