=begin rdoc
A User is a #Contact with a login and password. There are two special users :
[anon] user_id=1. Anonymous user. Becomes the owner of anything created without login.
[su] user_id=2. This user has full access to all the content in zena. He/she can read/write/destroy
      about anything. Even private content can be read/edited/removed by su. <em>This user should
      only be used for emergency purpose</em>. This is why an ugly warning is shown on all pages when
      logged in as su.
If you want to give administrative rights to a user, simply put him into the _admin_ group.
TODO: when a user is 'destroyed', pass everything he owns to another user or just mark the user as 'deleted'...
=end
class User < ActiveRecord::Base
  has_and_belongs_to_many :groups
  has_many                :nodes
  has_many                :versions
  validates_uniqueness_of :login
  validates_length_of     :login, :minimum=>4, :message=>"please choose a longer login"
  validates_presence_of   :password
  after_create            :add_public_group
  before_save             :set_lang
  before_destroy          :dont_destroy_su_or_anon
  
  class << self
    # Returns the logged in user or nil if login and password do not match
    def login(login, password)
      if !login || !password || login == "" || password == ""
        nil
      else
        user = find(:first, :conditions=>['login=? and password=?',login, hash_password( password )])
        # do not allow 'anonymous' login (user_id = 1 is the anonymous login)
        user if user && user.id.to_i != 1
      end
    end

    # Do not store clear passwords in the database (salted hash) :
    def hash_password(string)
      Digest::SHA1.hexdigest(string + ZENA_ENV[:password_salt])
    end
  end
  
  # Full contact name to show in views.
  def fullname
    first_name + " " + name
  end

  def initials
    fullname.split(" ").map {|w| w[0..0].capitalize}.join("")
  end
  
  def email
    self[:email] || ""
  end

  
  def password=(string)
    unless string.nil? || string == ''
      self[:password] = User.hash_password(string)
    else
      self[:password] = nil
    end
  end
  
  # Returns a list of the group ids separated by commas for the user (this is used mainly in SQL clauses).
  def group_ids
    return @group_ids if @group_ids
    res = if id==2
      # su user
      Group.find(:all)
    else
      if !new_record? && Group.find_by_sql("SELECT * FROM groups_users WHERE group_id=2 AND user_id = #{id}") != []
        # user is in admin group
        Group.find(:all)
      else
        # normal operation
        groups
      end
    end.map{|g| g[:id]}
    res << 1 unless res.include?(1)
    @group_ids = res
  end
  
  ### ================================================ ACTIONS AND OWNED ITEMS
  
  def comments_to_publish
    if id == 2
      # su can view all
      Comment.find_all_by_status(Zena::Status[:prop])
    else
      Comment.find(:all, :select=>'comments.*, nodes.name', :from=>'comments, nodes, discussions',
                   :conditions=>"comments.status = #{Zena::Status[:prop]} AND discussions.node_id = nodes.id AND comments.discussion_id = discussions.id AND nodes.pgroup_id IN (#{group_ids.join(',')})")
    end
  end
  
  # List all versions proposed for publication that the user has the right to publish.
  def to_publish
    if id == 2
      # su can view all
      Version.find_all_by_status(Zena::Status[:prop])
    else
      Version.find_by_sql("SELECT versions.* FROM versions LEFT JOIN nodes ON node_id=nodes.id WHERE status=#{Zena::Status[:prop]} AND nodes.pgroup_id IN (#{group_ids.join(',')})")
    end
  end
  
  # List all versions owned that are currently being written (status= +red+)
  def redactions
    if id == 2
      # su is master of all
      Version.find_all_by_status(Zena::Status[:red])
    else
      Version.find_all_by_user_id_and_status(id,Zena::Status[:red])
    end
  end
  
  # List all versions owned that are currently being written (status= +red+)
  def proposed
    if id == 2
      # su is master of all
      Version.find_all_by_status(Zena::Status[:prop])
    else
      Version.find_all_by_user_id_and_status(id,Zena::Status[:prop])
    end
  end
  
  ### ================================================ PRIVATE
  private
  
  # Make sure all users are in the _public_ group. This method is called +after_create+.
  def add_public_group #:doc:
    unless groups.map{|g| g[:id]}.include?(1)
      groups << Group.find(1)
    end
  end
  
  # Do not allow destruction of _su_ or _anon_ users. This method is called +before_destroy+.
  def dont_destroy_su_or_anon #:doc:
    raise Zena::AccessViolation, "su and Anonymous users cannot be destroyed !" if [1,2].include?(id)
  end
  
  # Prefered language must be set. It is set to the application default if none was given.
  def set_lang #:doc:
    unless self[:lang] && self.lang != ""
      self[:lant] = ZENA_ENV[:default_lang]
    end
  end
end
