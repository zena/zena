=begin rdoc
Comments can be added on a per discussion basis. There can be replies to other comments in the same
discussion. Comments are signed by the user commenting. Public comments
belong to the user _anon_ (see #User) and must have the 'athor_name' field set.

If ZENA_ENV[:moderate_anonymous_comments] is set, all public comments are set to 'prop' and are not directly seen on the site.
=end
class Comment < ActiveRecord::Base
  belongs_to :discussion
  validate   :valid_comment
  before_validation :comment_before_validation
  
  def author
    @author ||= secure(User) { User.find(self[:user_id]) }
  end
  
  def parent
    @parent ||= secure(Comment) { Comment.find(self[:reply_to]) }
  rescue ActiveRecord::RecordNotFound
    nil
  end
  
  # Remove the comment (set it's status to +rem+)
  def remove
    update_attributes( :status=> Zena::Status[:rem] )
  end
  
  # Publish the comment (set it's status to +pub+)
  # TODO: test
  def publish
    update_attributes( :status=> Zena::Status[:pub] )
  end
  
  def replies(opt={})
    if opt[:with_prop]
      conditions = ["reply_to = ? AND status > #{Zena::Status[:rem]}", self[:id]]
    else
      conditions = ["reply_to = ? AND status = #{Zena::Status[:pub]}", self[:id]]
    end
    Comment.find(:all, :conditions=>conditions, :order=>'created_at ASC')
  end
  
  private
  
    def comment_before_validation
      return false unless discussion
      self[:site_id] = discussion.node[:site_id]
      if new_record?
        if parent && (self[:title].nil? || self[:title] == '')
          self[:title] = TransPhrase['re:'][discussion.lang] + ' ' + parent.title
        end
        if visitor.moderated?
          self[:status] = Zena::Status[:prop]
        else
          self[:status] = Zena::Status[:pub]
        end
        
        self[:author_name] = nil unless visitor.is_anon?
      end
      
      self[:user_id] = visitor[:id]
    end
    
    def valid_comment
      errors.add('text', "can't be blank") unless self[:text] && self[:text] != ''
      errors.add('title', "can't be blank") unless self[:title] && self[:title] != ''
      errors.add('discussion', 'invalid') unless discussion
      if author.is_anon?
        errors.add('author_name', "can't be blank") unless self[:author_name] && self[:author_name] != ""
      end
    end
  
end
