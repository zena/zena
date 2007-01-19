=begin rdoc
Groups are used for access control. Two groups cannot be destroyed and have a special meaning in Zena :
[public] group with id=1. Access for this group is granted to all visitors regardless of user login.
[admin] group with id=2. A user in this group is automatically added to all groups. He/she can add or remove
        users, change user groups, monitor content, etc.
=end
class Group < ActiveRecord::Base
  has_and_belongs_to_many :users, :order=>'login'
  validates_presence_of   :name
  validates_uniqueness_of :name
  before_destroy          :dont_destroy_public_or_admin
  
  # TODO: test
  def user_ids
    @user_ids ||= if id==1
      # public user
      User.find(:all)
    else
      users
    end.map{|u| u[:id]}
  end
  
  private  
  # Public and admin groups are special. They cannot be destroyed.
  def dont_destroy_public_or_admin
    raise "'admin' or 'public' groups cannot be destroyed" if [1,2].include? id
  end
end
