=begin rdoc
A User is a #Contact with a login and password. There are two special users :
[anon] user_id=1. Anonymous user. Becomes the owner of anything created without login.
[su] user_id=2. This user has full access to all the content in zena. He/she can read/write/destroy
      about anything. Even private content can be read/edited/removed by su. <em>This user should
      only be used for emergency purpose</em>. This is why an ugly warning is shown on all pages when
      logged in as su.
If you want to give administrative rights to a user, simply put him into the _admin_ group.
TODO: when a user is 'destroyed', pass everything he owns to another user or just mark the user as 'deleted'...
TODO: when creating a user, define in which sites he belongs
=end
class User < ActiveRecord::Base
  attr_accessor           :visited_node_ids
  attr_accessor           :visitor
  attr_accessor           :site
  has_and_belongs_to_many :groups
  has_many                :nodes
  has_many                :versions
  # DO NOT SET has_many :sites  or make sure all set/remove user from sites is secure.
  # TODO: test link between user and contact
  belongs_to              :contact
  validate                :valid_user
  before_create           :add_default_groups
  before_destroy          :dont_destroy_su_or_anon
  
  class << self
    # Returns the logged in user or nil if login and password do not match
    def login(login, password, site)
      if !login || !password || login == "" || password == ""
        nil
      else
        # FIXME: test
        user = find(:first, :conditions=>['login=? and password=?',login, hash_password( password )])
        return nil unless user
        puts "User found"
        return nil unless Site.find(:first, :from=>"sites_users", :conditions=>["site_id = ? AND user_id = ?",site[:id],user[:id]])
        user.site = site
        return nil if user.is_anon? # no anonymous login !!
        # OK
        user
      end
    end

    # Do not store clear passwords in the database (salted hash) :
    def hash_password(string)
      Digest::SHA1.hexdigest(string + PASSWORD_SALT)
    end
  end
  
  def visit(node, opts={})
    node.visitor = self
    # keep track of the nodes connected to this visit to build the 'expire_with' list
    visited_node_ids << node[:id] if is_anon? && CachedPage.perform_caching
  end
  
  def visited_node_ids
    @visited_node_ids ||= []
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
  
  # TODO: test (replace by admin?) 
  # FIXME: site_id
  def is_admin?
    (self[:id] == 2) || self.group_ids.include?(2)
  end
  
  # Return true if the user is the anonymous user for the current visited site
  def is_anon?
    # tested in site_test
    (@site || visitor.site).anon_id == self[:id] && (!new_record? || login.nil?)# (when creating a new site, anon_id == nil)
  end
  
  # Return true if the user is the super user for the current visited site
  def is_su?
    # tested in site_test
    visitor.site.su_id == self[:id]
  end
  
  # Returns a list of the group ids separated by commas for the user (this is used mainly in SQL clauses).
  def group_ids
    return @group_ids if @group_ids
    if id==2
      # su user
      res = Group.find(:all)
    else
      if !new_record? && Group.find_by_sql("SELECT * FROM groups_users WHERE group_id=2 AND user_id = #{id}") != []
        # user is in admin group
        res = Group.find(:all)
      else
        # normal operation
        res = groups
      end
    end
    res = res.map{|g| g[:id]}
    res << 1 unless res.include?(1)
    res << 3 unless res.include?(3) || id == 1 # all logged in users are in the 'site' group except 'anon'
    @group_ids = res
  end
  
  #TODO: test
  # return only the ids of the groups really set (not all groups for admin or the like)
  def group_set_ids
    @set_group_ids ||= groups.map{|g| g[:id]}
  end
  
  # TODO: test
  def tz
    @tz ||= TimeZone.new(self[:time_zone] || '') || TimeZone.new("Bern")
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
  
  # TODO: test
  # FIXME: with site_id
  def valid_user
    if is_anon?
      # Anonymous user *must* have an empty login
      self[:login] = nil
      self[:password] = nil
    else
      if new_record?
        # FIXME: how to handle unique 'login' through many sites ?
        # Refuse to add a user in a site if already a user with same login.
        # validate uniqueness of 'login'
        if User.find(:first, :conditions=>["login = ?", self[:login]])
          errors.add(:login, 'has already been taken')
        end
        # validate uniqueness of 'login'
        if User.find(:first, :conditions=>["login = ?", self[:login]])
          errors.add(:login, 'has already been taken')
        end
      else
        # get old password
        old = User.find(self[:id])
        self[:password] = old[:password] if self[:password].nil? || self[:password] == ""
        # validate uniqueness of 'login'
        if User.find(:first, :conditions=>["login = ? AND id <> ?", self[:login], self[:id]])
          errors.add(:login, 'has already been taken')
        end
        # FIXME: we measure length of the hashed content !!
        errors.add(:login, 'too short') unless self[:login] == old[:login] || (self[:login] && self[:login].length > 3)
      end
      errors.add(:password, 'too short') unless self[:password] && self[:password].length > 4
    end
  end
  
  # Make sure all users are in the _public_ and _site_ groups. This method is called +after_create+.
  def add_default_groups #:doc:
    return if is_su?
    g_ids = groups.map{|g| g[:id]}
    groups << visitor.site.public_group unless g_ids.include?(visitor.site.public_group_id)
    groups << visitor.site.site_group unless g_ids.include?(visitor.site.site_group_id) || is_anon?
  end
  
  # Do not allow destruction of _su_ or _anon_ users. This method is called +before_destroy+.
  def dont_destroy_su_or_anon #:doc:
    raise Zena::AccessViolation, "su and Anonymous users cannot be destroyed !" if [1,2].include?(id)
  end
  
  def visitor
    return @visitor if @visitor
    raise Zena::RecordNotSecured.new("Visitor not set, record not secured.")
  end
  
  def old
    @old ||= self.class.find(self[:id])
  end
end
