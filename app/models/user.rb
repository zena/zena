=begin rdoc
There are two special users :
[anon] Anonymous user. Used to set defaults for newly created users.
[su] This user has full access to all the content in zena. He/she can read/write/destroy
      about anything. Even private content can be read/edited/removed by su. <em>This user should
      only be used for emergency purpose</em>. This is why an ugly warning is shown on all pages when
      logged in as su.
If you want to give administrative rights to a user, simply put him into the _admin_ group.

Users have access rights defined by the groups they belong to. They also have a 'status' indicating the kind of
things they can/cannot do :
[:user]        (60): can read/write/publish
[:commentator] (40): can write comments
[:moderated]   (30): can write moderated comments
[:reader]      (20): can only read
[:deleted]     ( 0): cannot login

TODO: when a user is 'destroyed', pass everything he owns to another user or just mark the user as 'deleted'...
TODO: when creating a user, define in which sites he belongs
=end
class User < ActiveRecord::Base
  attr_accessible         :login, :password, :lang, :contact_id, :first_name, :name, :email, :time_zone, :status
  attr_accessor           :visited_node_ids
  attr_accessor           :site
  has_and_belongs_to_many :groups
  has_many                :nodes
  has_many                :versions
  has_and_belongs_to_many :sites
  # TODO: test link between user and contact
  belongs_to              :contact
  before_validation       :user_before_validation
  validate                :valid_user
  before_create           :add_default_groups
  before_destroy          :dont_destroy_su_or_anon
  
  Status = {
    :user        => 60,
    :commentator => 40,
    :moderated   => 30,
    :reader      => 20,
    :deleted     => 0,
  }
  class << self
    # Returns the logged in user or nil if login and password do not match
    def login(login, password, site)
      if !login || !password || login == "" || password == ""
        nil
      else
        user = find(:first, :select=>"users.*", :from=>'users, sites_users', :conditions=>['login=? AND password=? AND sites_users.user_id = users.id AND sites_users.site_id = ?',login, hash_password(password), site[:id]])
        return nil unless user && user.reader?
        user.site    = site
        return nil if user.is_anon? # no anonymous login !!
        # OK
        user
      end
    end

    # Do not store clear passwords in the database (salted hash) :
    def hash_password(string)
      Digest::SHA1.hexdigest(string + PASSWORD_SALT)
    end
    
    # TODO: make sure new user defaults are set to anonymous user
  end
  
  def visit(obj, opts={})
    obj.visitor = self
    # keep track of the nodes connected to this visit to build the 'expire_with' list
    visited_node_ids << obj[:id] if is_anon? && CachedPage.perform_caching && obj.kind_of?(Node)
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
    if string.nil? || string == ''
      self[:password] = nil
    elsif string && string.length > 4
      self[:password] = User.hash_password(string)
    else
      @password_too_short = true
    end
  end
  
  # TODO: test (replace by admin?) 
  # FIXME: site_id
  def is_admin?
    @is_admin ||= visitor_site.admin_group.user_ids.include?(self[:id])
  end
  
  # Return true if the user is the anonymous user for the current visited site
  def is_anon?
    # tested in site_test
    visitor_site.anon_id == self[:id] && (!new_record? || login.nil?)# (when creating a new site, anon_id == nil)
  end
  
  # Return true if the user is the super user for the current visited site
  def is_su?
    # tested in site_test
    visitor_site.su_id == self[:id]
  end
  
  # Return true if the user's status is high enough to start editing nodes.
  # TODO: test
  def user?
    status >= User::Status[:user]
  end
  
  # Return true if the user's status is high enough to write comments.
  def commentator?
    status >= User::Status[:moderated]
  end

  # Return true if the user's comments should be moderated.
  def moderated?
    status < User::Status[:commentator]
  end
  
  # Return true if the user's status is high enough to read. This is basically the same as
  # not deleted?.
  # TODO: test
  def reader?
    status >= User::Status[:reader]
  end
  
  # Return true if the user is deleted and should not be allowed to login.
  # TODO: test
  def deleted?
    status == User::Status[:deleted]
  end
  
  # Returns a list of the group ids separated by commas for the user (this is used mainly in SQL clauses).
  def group_ids
    return @group_ids if @group_ids
    if is_su?
      # su user
      res = visitor_site.groups.map{|g| g[:id]}
    else
      # normal operation
      res = groups.find(:all, :conditions=>["site_id = ?", visitor_site[:id]], :order=>'name').map{|g| g[:id]} # only groups from the current site
      if res.include?(visitor_site[:admin_group_id])
        # admin user, find all groups
        res = visitor_site.groups.map{|g| g[:id]}
      end
    end
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
  
  # Set user defaults.
  def user_before_validation
    if self[:status].nil? || self[:status] == ""
      self[:status] = User::Status[:user]
    end
  end
  
  # Returns the current site (self = visitor) or the visitor's site
  def visitor_site
    @site || visitor.site
  end
  
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
        if visitor_site.users.find_by_login(self[:login])
          errors.add(:login, 'has already been taken')
        end
        Node.logger.info "===============>>>>>>>>>>>>>>>>>============="
      else
        # get old password
        old = User.find(self[:id])
        self[:password] = old[:password] if self[:password].nil? || self[:password] == ""
        # validate uniqueness of 'login' through all sites
        sites.each do |site|
          if site.users.find(:first, :conditions=>["login = ? AND id <> ?", self[:login], self[:id]])
            errors.add(:login, 'has already been taken')
          end
        end
        errors.add(:login, 'too short') unless self[:login] == old[:login] || (self[:login] && self[:login].length > 3)
      end
      if @password_too_short
        errors.add(:password, 'too short')
        remove_instance_variable :@password_too_short
      end
    end
  end
  
  # Make sure all users are in the _public_ and _site_ groups. This method is called +before_create+.
  def add_default_groups #:doc:
    sites << visitor_site
    
    return if is_su?
    g_ids = groups.map{|g| g[:id]}
    groups << visitor_site.public_group unless g_ids.include?(visitor_site.public_group_id)
    groups << visitor_site.site_group unless g_ids.include?(visitor_site.site_group_id) || is_anon?
  end
  
  # Do not allow destruction of _su_ or _anon_ users. This method is called +before_destroy+.
  def dont_destroy_su_or_anon #:doc:
    raise Zena::AccessViolation, "su and Anonymous users cannot be destroyed !" if visitor_site.protected_user_ids.include?(id)
  end
  
  def old
    @old ||= self.class.find(self[:id])
  end
end
