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
  
  zafu_readable           :name
  
  attr_accessible         :name, :user_ids # FIXME: add user_ids ? + add users validation (are in site)
  has_and_belongs_to_many :users, :order=>'login'
  validates_presence_of   :name
  validate                :valid_group
  validates_uniqueness_of :name, :scope => :site_id # TODO: test
  before_destroy          :dont_destroy_public_or_admin
  belongs_to              :site
  
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
    User.find(:all, :conditions => "groups_users.group_id = #{self[:id]} AND participations.status > #{User::Status[:deleted]}",
                    :joins => "INNER JOIN groups_users ON users.id = groups_users.user_id INNER JOIN participations ON participations.user_id = users.id")
  end
  
  private  
  # Public and admin groups are special. They cannot be destroyed.
  def dont_destroy_public_or_admin
    raise Zena::AccessViolation.new("'admin', 'site' or 'public' groups cannot be destroyed") if visitor.site.protected_group_ids.include?( id )
  end
  
  # Make sure only admins can create/update groups.
  def valid_group
    unless visitor.is_admin?
      errors.add('base', 'you do not have the rights to do this') 
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
        user = secure!(User) { User.find(id) }
        unless user.site_ids.include?(self[:site_id])
          errors.add('user', 'not found') 
          next
        end
        self.users << user
        visitor_added = user[:id] == visitor[:id]
      end
    end
    return errors.empty?
  rescue ActiveRecord::RecordNotFound  
    errors.add('user', 'not found')
    false
  end
  
  def before_save
    self.visitor # make sure visitor is set
  end
end
