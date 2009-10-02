=begin rdoc
Comments can be added on a per discussion basis. There can be replies to other comments in the same
discussion. Comments are signed by the user commenting. Public comments
belong to the user _anon_ (see #User) and must have the 'athor_name' field set.

If anonymous is moderated (User#moderated?), all public comments are set to 'prop' and are not directly seen on the site.
=end
class Comment < ActiveRecord::Base

  attr_public        :title, :text, :author_name, :created_at, :updated_at, :status, :discussion_zip
  zafu_context       :replies => ["Comment"], :node => "Node"
  attr_accessible    :title, :text, :author_name, :discussion_id, :reply_to, :status

  belongs_to :discussion
  validate   :valid_comment
  before_validation :comment_before_validation
  after_save :sweep_cache

  def author
    @author ||= secure(User) { User.find(self[:user_id]) }
  end

  def node
    @node ||= discussion.node
  end

  def author_name
    self[:author_name] || (self[:user_id] ? author.fullname : nil)
  end

  def parent
    @parent ||= self[:reply_to] ? secure(Comment) { Comment.find(self[:reply_to]) } : nil
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
      conditions = ["reply_to = ? AND status >= #{Zena::Status[:pub]}", self[:id]]
    else
      conditions = ["reply_to = ? AND status = #{Zena::Status[:pub]}", self[:id]]
    end
    secure(Comment) { Comment.find(:all, :conditions=>conditions, :order=>'created_at ASC') }
  end

  # needed by zafu for ajaxy stuff
  def zip
    self[:id]
  end

  # needed by zafu to group
  def discussion_zip
    self[:discussion_id]
  end

  # TODO: test
  def can_write?
    is_author? && discussion.open?
  end

  private

    def is_author?
      visitor.is_anon? ? visitor.ip == self[:ip] : visitor[:id] == user_id
    end

    def comment_before_validation
      return false unless discussion
      if new_record?
        self[:site_id] = discussion.node[:site_id]
        if parent && self[:title].blank?
          self[:title] = _('re: ') + parent.title
        end
        if visitor.moderated?
          self[:status] = Zena::Status[:prop]
        else
          self[:status] = Zena::Status[:pub]
        end

        self[:user_id] = visitor[:id]
        self[:author_name] = nil unless visitor.is_anon?
        self[:ip] = visitor.ip if visitor.is_anon?
      end
    end

    def valid_comment
      if new_record?
        errors.add('base', 'you cannot comment here') unless visitor.commentator? && discussion && discussion.open?
      else
        if discussion.node.can_drive?
          # OK
          # can edit/delete comments
          # TODO: should be restricted to 'delete' or 'erase text'...
        elsif is_author?
          errors.add('base', 'discussion closed, comment cannot be updated') if !can_write?
        else
          errors.add('base', 'You do not have the rights to do this.')
        end
      end
      errors.add('text', "can't be blank") if self[:text].blank?
      errors.add('discussion', 'invalid') unless discussion
      errors.add('ip', "can't be blank") unless self[:ip] || !visitor.is_anon?
      if author.is_anon?
        errors.add('author_name', "can't be blank") unless self[:author_name] && self[:author_name] != ""
      end
    end

    def sweep_cache
      discussion.node.sweep_cache
    end

end
