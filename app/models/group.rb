=begin rdoc
Groups are used for access control. Two groups cannot be destroyed and have a special meaning in Zena :
[public] group with id=1. Access for this group is granted to all visitors regardless of user login.
[admin] group with id=2. A user in this group is automatically added to all groups. He/she can add or remove
        users, change user groups, monitor content, etc.
=end
class Group < ActiveRecord::Base
  has_and_belongs_to_many :users
  before_destroy :dont_destroy_public_or_admin
  
  private  
  # Public and admin groups are special. They cannot be destroyed.
  def dont_destroy_public_or_admin
    raise "'admin' or 'public' groups cannot be destroyed" if [1,2].include? id
  end
end
