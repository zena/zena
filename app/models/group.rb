=begin rdoc
Groups are used for access control. They cannot be used cross-site like users.

Three groups cannot be destroyed and have a special meaning in each site (set in Site) :
+public+:: Access for this group is granted to all visitors regardless of user login.
+site+:: All users except anonymous user are in this group. It is the 'logged in' users' group.
+admin+:: A user in this group is automatically added to all groups. He/she can add or remove
        users, change user groups, monitor content, etc.

Only administrators can change groups. An administrator cannot remove him/herself from the admin group.
=end
class Group < ActiveRecord::Base

  include RubyLess
  safe_method             :name => String
  attr_accessible         :name, :user_ids, :replace_by # FIXME: add user_ids ? + add users validation (are in site)
  has_and_belongs_to_many :users, :order=>'login'
  validates_presence_of   :name
  validate                :valid_group
  validates_uniqueness_of :name, :scope => :site_id # TODO: test
  before_save             :do_replace_by
  before_destroy          :check_can_destroy
  belongs_to              :site

  # FIXME: test translate_pseudo_id for groups
  def self.translate_pseudo_id(id,sym=:id)
    str = id.to_s
    if str =~ /\A\d+\Z/
      # id
      Zena::Db.fetch_attribute("SELECT #{sym} FROM groups WHERE site_id = #{current_site[:id]} AND id = '#{str}'")
    elsif str =~ /\A([a-zA-Z ]+)(\+*)\Z/
      Zena::Db.fetch_attribute("SELECT groups.#{sym} FROM groups WHERE site_id = #{current_site[:id]} AND name LIKE #{self.connection.quote("#{$1}%")} LIMIT 1 OFFSET #{$2.size}")
    else
      nil
    end
  end

  # Return true if the group is the public group of the site.
  def public_group?
    self[:id] == visitor.site[:public_group_id]
  end

  # Return true if the group is the site group.
  def site_group?
    self[:id] == visitor.site[:site_group_id]
  end

  def user_ids
    @user_ids ||= users.map {|r| r[:id]}
  end

  def user_ids=(list)
    @defined_user_ids = list
  end

  alias o_users users
  def users
    @users ||= begin
      usr = o_users
      usr.each do |r|
        r[:password] = nil
      end
      usr
    end
  end

  def active_users
    User.find(:all, :conditions => ['groups_users.group_id = ? AND status > ?', self.id, User::Status[:deleted]],
                    :joins => 'INNER JOIN groups_users ON users.id = groups_users.user_id')
  end

  # Replace all uses of the group (rgroup_id, wgroup_id, dgroup_id) by another group.
  def replace_by=(group_id)
    @replace_by = group_id unless group_id.blank?
  end

  def replace_by
    @replace_by
  end

  def can_destroy?
    clause = [:rgroup_id, :wgroup_id, :dgroup_id].map{|g| "#{g} = '#{self[:id]}'"}.join(" OR ")
    if 0 == self.class.count_by_sql("SELECT COUNT(*) FROM #{Node.table_name} WHERE #{clause}")
      return true
    else
      errors.add('base', 'this group is used by node access definitions')
      return false
    end
  end

  private
    # Public and admin groups are special. They cannot be destroyed.
    def check_can_destroy
      # do not destroy admin or public groups
      raise Zena::AccessViolation.new("'admin', 'site' or 'public' groups cannot be destroyed") if visitor.site.protected_group_ids.include?( id )
      return can_destroy?
    end

    # Make sure only admins can create/update groups.
    def valid_group
      unless visitor.is_admin?
        errors.add('base', 'You do not have the rights to do this.')
        return false
      end

      # make sure site_id is set
      self[:site_id] = visitor.site[:id]

      # Make sure all users are in the group's site.
      if @defined_user_ids
        if public_group? || site_group?
          errors.add('base', 'you cannot add or remove users from this group')
          return false
        end

        self.users    = []
        visitor_added = false
        @defined_user_ids.each do |id|
          unless user = secure(User) { User.find(:first, :conditions => ['users.id = ?', id]) }
            errors.add('user', 'not found')
            next
          end
          self.users << user
          visitor_added = user[:id] == visitor[:id]
        end
      end
      return errors.empty?
    end

    def do_replace_by
      if @replace_by
        if group = secure(Group) { Group.find(:first, :conditions => ["id = ? ", @replace_by]) }
          [:rgroup_id, :wgroup_id, :dgroup_id].each do |key|
            Node.connection.execute "UPDATE #{Node.table_name} SET #{key} = '#{group[:id]}' WHERE #{key} = '#{self[:id]}'"
          end
        else
          errors.add('replace_by', 'group not found')
        end
        @replace_by_group_on_save = nil
      end
      return errors.empty?
    end
end
