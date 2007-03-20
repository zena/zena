=begin rdoc
Groups are used for access control. Two groups cannot be destroyed and have a special meaning in Zena :
[public] group with id=1. Access for this group is granted to all visitors regardless of user login.
[admin] group with id=2. A user in this group is automatically added to all groups. He/she can add or remove
        users, change user groups, monitor content, etc.
=end
class Group < ActiveRecord::Base
  attr_accessible         :name # FIXME: add user_ids ? + add users validation (are in site)
  has_and_belongs_to_many :users, :order=>'login'
  validates_presence_of   :name
  validate                :valid_group
  validates_uniqueness_of :name, :scope => :site_id # TODO: test
  before_destroy          :dont_destroy_public_or_admin
  
  def public_group?
    self[:id] == visitor.site[:public_group_id]
  end
  
  def admin_group?
    self[:id] == visitor.site[:admin_group_id]
  end
  
  def site_group?
    self[:id] == visitor.site[:site_group_id]
  end
  
  def user_ids
    @user_ids ||= users.map {|r| r[:id]}
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
  
  private  
  # Public and admin groups are special. They cannot be destroyed.
  def dont_destroy_public_or_admin
    raise Zena::AccessViolation.new("'admin', 'site' or 'public' groups cannot be destroyed") if visitor.site.protected_group_ids.include?( id )
  end
  
  # TODO: test
  # TODO: test secure (group can be created in this site...)
  def valid_group
    self[:site_id] = visitor.site[:id]
  end
end
