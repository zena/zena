require 'digest/sha1'
require 'tzinfo'
require 'authlogic/crypto_providers/bcrypt'

=begin rdoc
There are two special users in each site :
[anon] Anonymous user. Used to set defaults for newly created users.
[su] This user has full access to all the content in zena. He/she can read/write/destroy
      about anything. Even private content can be read/edited/removed by su. <em>This user should
      only be used for emergency purpose</em>. This is why an ugly warning is shown on all pages when
      logged in as su.

If you want to give administrative rights to a user, simply put him/her into the _admin_ group.

Users have access rights defined by the groups they belong to. They also have a 'status' indicating the kind of
things they can/cannot do :
+:admin+::       (60): can read/write/publish in any group, can create users/groups
+:user+::        (50): can read/write/publish
+:commentator+:: (40): can write comments
+:moderated+::   (30): can write moderated comments
+:reader+::      (20): can only read
+:deleted+::     ( 0): cannot login

TODO: when a user is 'destroyed', pass everything he owns to another user or just mark the user as 'deleted'...
=end
class User < ActiveRecord::Base
  attr_accessor :zafu_cache, :asset_host
  
  include Property
  RESCUE_SKIN_ID = -1
  ANY_SKIN_ID    = 0
  ATTRIBUTES_FROM_PROFILE = [:group_ids, :status]

  property do |p|
    # nil ==> no dev mode
    # -1  ==> rescue skin
    # 0   ==> dev mode with normal skin
    # xx  ==> fixed skin
    p.integer :dev_skin_id
  end

  acts_as_authentic do |c|
    #c.transition_from_crypto_providers = Zena::InitialCryptoProvider
    #c.crypto_provider = Authlogic::CryptoProviders::BCrypt
    c.crypto_provider = Zena::CryptoProvider::Initial
    c.validate_email_field = false
    c.validate_login_field = false
    c.require_password_confirmation = false
    c.validate_password_field = false
  end

  # Dynamic resolution of the author class from the prototype
  def self.node_user_proc
    Proc.new do |h, r, s|
      res = {:method => 'node', :nil => true}
      if prototype = visitor.prototype
        res[:class] = prototype.vclass
      else
        res[:class] = VirtualClass['Node']
      end
      res
    end
  end

  include RubyLess

  safe_attribute          :login, :time_zone, :created_at, :updated_at, :lang, :id
  safe_method             :status => Number, :status_name => String,
                          :is_anon? => Boolean, :is_admin? => Boolean, :is_manager? => Boolean, :user? => Boolean, :commentator? => Boolean,
                          :moderated? => Boolean, :asset_host? => Boolean, [:in_group?, String] => Boolean,
                          :group_names => [String], [:group_id_to_name, Number] => String, :site => Site

  safe_context            :node => node_user_proc,
                          :to_publish => ['Version'], :redactions => ['Version'], :proposed => ['Version'],
                          :comments_to_publish => ['Comment']

  attr_accessible         :login, :lang, :node, :time_zone, :status, :group_ids, :site_ids, :crypted_password, :password, :dev_skin_id, :node_attributes,
                          :login_attempt_count, :is_profile, :profile
  attr_accessor           :visited_node_ids
  attr_accessor           :ip

  belongs_to              :site
  belongs_to              :node, :dependent => :destroy # Do we want this ? (won't work if there are sub-nodes...)
  has_and_belongs_to_many :groups
  has_many                :nodes
  has_many                :versions

  before_validation       :user_before_validation
  validate                :valid_groups
  validate                :valid_user
  validate                :valid_node
  validates_uniqueness_of :login, :scope => :site_id

  before_destroy          :dont_destroy_protected_users
  validates_presence_of   :site_id
  before_create           :create_node
  after_save              :user_after_save

  Status = {
    :su          => 80,  # Not used
    :admin       => 60,  # Is in all groups, can access admin interface, etc
    :manager     => 55,  # Can manage other users. Cannot edit groups.
    :user        => 50,  # Can write articles + publish (depends on access rights)
    :commentator => 40,  # Can write comments
    :moderated   => 30,  # Can write comments (moderated)
    :reader      => 20,  # Can read
    :deleted     => 0,
  }.freeze
  Num_to_status = Hash[*Status.map{|k,v| [v,k]}.flatten].freeze


  class << self
    # This method is used by authlogic and is only called from withing a Secure scope that
    # enforces the proper site_id.
    def find_allowed_user_by_login(login)
      first(:conditions=>["login = ? and status > 0", login])
    end

    # Creates a new user without setting the defaults (used to create the first users of the site). Use
    # new instead.
    alias new_no_defaults new

    # Creates a new user with the defaults set from the anonymous user.
    def new(attrs={})
      new_attrs = attrs.dup
      anon = visitor.site.anon

      # Set new user defaults based on the anonymous user.
      [:lang, :time_zone, :status].each do |sym|
        new_attrs[sym] = anon.send(sym) if attrs[sym].blank? && attrs[sym.to_s].blank?
      end
      super(new_attrs)
    end

  end

  def node_with_secure
    @node ||= secure(Node) { node_without_secure }
  end
  alias_method_chain :node, :secure


  # Each time a node is found using secure (Zena::Acts::Secure or Zena::Acts::SecureNode), this method is
  # called to set the visitor in the found object. This is also used to keep track of the opened nodes
  # when rendering a page for the cache so we can know when to expire the cache.
  def visit(obj, opts={})
    if obj.kind_of? Node
      obj.visitor = self #explicit visit
      # keep track of the nodes connected to this visit to build the 'expire_with' list
      visited_node_ids << obj[:id]
    end
  end

  def visited_node_ids
    @visited_node_ids ||= []
  end

  # Return the prototype user (used by Zafu and QueryBuilder to know the class
  # of the visitor and during user creation)
  def prototype
    @prototype ||= begin
      secure(Node) { Node.new_node(prototype_attributes) }
    end
  end

  # Return a new Node to be used by a new User as base for creating the visitor Node.
  def prototype_attributes
    @prototype_attributes ||= begin
      attrs = begin
        if code = current_site.prop['usr_prototype_attributes']
          hash = safe_eval(code)
          if hash.kind_of?(Hash)
            hash
          else
            {}
          end
        else
          {}
        end
      rescue RubyLess::Error => err
        {}
      end

      # This is a security feature to avoid :_parent_id set manually in usr_prototype_attributes.
      attrs.stringify_keys!
      unless attrs['parent_id']
        attrs[:_parent_id] = current_site[:root_id]
      end

      attrs['klass'] ||= attrs.delete('class') || 'Node'

      attrs
    end
  end

  def node_attributes=(node_attrs)
    node_attrs.stringify_keys!
    if !node_attrs['id'].blank?
      @node = secure!(Node) { Node.find_node_by_pseudo(node_attrs.delete('id')) }
      self[:node_id] = @node.id
    elsif self[:node_id]
      @node = secure!(Node) { node_without_secure }
    else
      @node = secure(Node) { Node.new_node(prototype_attributes) }
    end
    @node.attributes = node_attrs || {}
  end

  def status_name
    Num_to_status[status].to_s
  end

  # Return true if the user is in the admin group or if the user is the super user.
  def is_admin?
    status.to_i >= User::Status[:admin]
  end
  
  # Has user administration rights
  def is_manager?
    status.to_i >= User::Status[:manager]
  end

  # Return true if the user is the anonymous user for the current visited site
  def is_anon?
    # tested in site_test
    user_site.anon_id == self[:id] && (!new_record? || self[:login].nil?) # (when creating a new site, anon_id == nil)
  end
  
  # This is set on the user during login.
  alias asset_host? asset_host
  
  def group_names
    @group_names ||= begin
      groups.all(:order=>'name').map(&:name)
    end
  end
  
  # Return the name of a group for a given id. If the visitor is not in the group,
  # the method returns nil
  def group_id_to_name(id)
    (@group_ids_to_name ||= Hash[*all_groups.map{|g| [g.id, g.name]}.flatten])[id]
  end
  
  def in_group?(name)
    group_names.include?(name)
  end
  
  def reload_groups!
    @group_ids  = nil
    @all_groups = nil
  end

  # Return true if the user's status is high enough to start editing nodes.
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

  # Return true if the visitor is allowed API acces
  def api_authorized?
    group_ids.include?(current_site.api_group_id)
  end

  # Returns a list of the group ids separated by commas for the user (this is used mainly in SQL clauses).
  # TODO: Performance
  #
  # Zena::Db.fetch_ids("SELECT id FROM groups WHERE site_id = #{current_site.id} ORDER BY name ASC")
  # Zena::Db.fetch_ids("SELECT group_id FROM groups_users WHERE user_id = #{id} ORDER BY name ASC", 'group_id')
  def group_ids
    @group_ids ||= all_groups.map(&:id)
  end
  
  # Return all groups in which the user belongs directly or indirectly (admin).
  def all_groups
    @all_groups ||= if is_admin?
      site.groups.all(:order => 'name')
    else
      groups.all(:order => 'name')
    end
  end

  # Define the groups the user belongs to.
  def group_ids=(list)
    # We have to do our own method to avoid rails loading groups which will not be secured.
    @defined_group_ids = list
  end

  def time_zone=(tz)
    self[:time_zone] = tz.blank? ? nil : tz
    @tz = nil
  end

  #TODO: test
  # return only the ids of the groups really set (not all groups for admin or the like)
  def group_set_ids
    @group_set_ids ||= groups.map{|g| g[:id]}
  end

  # TODO: test
  def tz
    @tz ||= TZInfo::Timezone.get(self[:time_zone] || "UTC")
  rescue TZInfo::InvalidTimezoneIdentifier
    @tz = TZInfo::Timezone.get("UTC")
  end

  def comments_to_publish
    secure(Comment) { Comment.find(:all, :select=>'comments.*', :from=>'comments, nodes, discussions',
                   :conditions => ['comments.status = ? AND discussions.node_id = nodes.id AND comments.discussion_id = discussions.id AND nodes.dgroup_id IN (?)', Zena::Status::Prop, visitor.group_ids]) }
  end

  # List all versions proposed for publication that the user has the right to publish.
  def to_publish
    secure(Version) { Version.find(:all, :conditions => ['status = ? AND nodes.dgroup_id IN (?)', Zena::Status::Prop, visitor.group_ids]) }
  end

  # List all versions owned that are currently being written (status= +red+)
  def redactions
    secure(Version) { Version.find(:all, :conditions => ['status = ? AND versions.user_id = ?', Zena::Status::Red, self.id]) }
  end

  # List all versions owned that are currently being proposed (status= +prop+)
  def proposed
    secure(Version) { Version.find(:all, :conditions => ['status = ? AND versions.user_id = ?', Zena::Status::Prop, self.id]) }
  end

  def get_skin(node)
    skin_zip = is_admin? ? dev_skin_id.to_i : 0

    case skin_zip
    when RESCUE_SKIN_ID
      # rescue skin
      nil
    when ANY_SKIN_ID
      # normal skin
      current_site.skin || node.skin || (node.parent ? node.parent.skin : nil)
    else
      # find skin from zip
      secure(Skin) { Skin.find_by_zip(skin_zip)}
    end
  end

  def find_node(path, zip, name, request, need_write = false)
    secure!(Node) do
      if name =~ /^\d+$/
        Node.find_by_zip(name)
      elsif name
        basepath = (path[0..-2] + [name]).map {|p| String.from_url_name(p) }.join('/')
        Node.find_by_path(basepath) ||
        Node.find_by_path(basepath, current_site.root_id, true)
      else
        Node.find_by_zip(zip)
      end
    end
  end

  def dev_mode?
    !dev_skin_id.blank?
  end
  
  def profile=(m)
    if !visitor.is_manager?
      # Make sure the user is a manager before changing profile
      @profile_error = _('Cannot be changed')
    elsif m.blank?
      self[:profile_id] = nil
    else
      # Try to find profile user
      if profile = secure(User) { User.find_by_login_and_is_profile(m.to_s, true) }
        # Copy access definitions from profile to current user done during validation
        self[:profile_id] = profile.id
      else
        @profile_error = _('Cannot be found')
      end
    end
  end
  
  def profile_user
    @profile_user ||= secure(User) { User.find(self[:profile_id]) }
  end
  
  def profile
    profile_user ? profile_user.login : ''
  end

  private

    def user_site
      self.site || visitor.site # site when User is new
    end

    def create_node
      # do not try to create a node if the root node is not created yet
      return unless visitor.site.root_id
      # This happens if the user is created from the node[user] params.
      return if self[:node_id]
      @node.version.status = Zena::Status::Pub

      unless @node.save
        # What do we do with this error ?
        raise Zena::InvalidRecord, "Could not create contact node for user #{self.id} in site #{site_id} (#{@node.errors.map{|k,v| [k,v]}.join(', ')})"
      end

      unless @node.publish_from
        raise Zena::InvalidRecord, "Could not publish contact node for user #{user_id} in site #{site_id} (#{@node.errors.map{|k,v| [k,v]}.join(', ')})"
      end

      self.node_id = @node.id
    end

    # Set user defaults.
    def user_before_validation
      return true if current_site.being_created?

      self[:site_id] = visitor.site[:id]
      
      if self[:profile_id]
        # Copy elements
        profile = secure(User) { User.find(self[:profile_id] ) }
        ATTRIBUTES_FROM_PROFILE.each do |k|
          self.send(:"#{k}=", profile.send(k))
        end
        
        # Ignore setting (to avoid loops)
        if self[:is_profile]
          self[:profile_id] = nil
        end
      elsif @defined_group_ids && !visitor.is_admin?
        # Do not allow direct edition of groups by non-admin (even manager cannot do this).
        @defined_group_ids = nil
        @defined_group_ids_error = true
      end
      
      if new_record?
        self.status = site.anon.status if status.blank?
        self.lang   = site.anon.lang   if lang.blank?
      elsif status.blank?
        self.status   = site.anon.status
      end

      if login.blank? && !is_anon?
        self.login = self.node.title.strip
      end
      
      if !is_admin?
        # Make sure we remove dev_skin settings if user is not an admin.
        self.dev_skin_id = nil
      end
    end

    # Validates that anon user does not have a login, that other users have a password
    # and that the login is unique for the sites the user belongs to.
    def valid_user
      self[:site_id] = visitor.site[:id]

      if !site.being_created?
        if !visitor.is_manager? && visitor[:id] != self[:id]
          errors.add('base', 'You do not have the rights to do this.')
          return false
        elsif visitor.is_admin?
          # All OK
        elsif visitor.is_manager?
          # Changing status of users above or equal to manager not allowed
          if status_changed? && status >= User::Status[:manager]
            errors.add('base', 'You cannot set this status (too high).')
            return false
          end
          
          # Editing users above or equal to manager not allowed
          if status_was.to_i >= User::Status[:manager] && visitor.id != self.id
            errors.add('base', 'You cannot edit this user (high status).')
            return false
          end
        end
      end

      errors.add('lang', 'not available') unless site.lang_list.include?(lang)

      if is_anon?
        # Anonymous user *must* have an empty login
        self[:login]    = nil
        self[:crypted_password] = nil
      else
        if new_record?
          # Refuse to add a user in a site if already a user with same login.
          errors.add(:password, "can't be blank") if self[:crypted_password].nil? || self[:crypted_password] == ""
        else
          # get old password
          old = User.find(self[:id])
          self[:crypted_password] = old[:crypted_password] if self[:crypted_password].nil? || self[:crypted_password] == ""
          errors.add(:login, "can't be blank") if self[:login].blank?
          errors.add(:status, 'You cannot remove your own access rights.') if self[:id] == visitor[:id] && old.is_admin? && self.status.to_i != old.status
        end
      end

      if self[:time_zone]
        begin
          TZInfo::Timezone.get(self[:time_zone])
        rescue
          errors.add(:time_zone, 'invalid')
        end
      end
      
      if self.is_profile_was && !self.is_profile
        # Make sure there are no dependant users
        if secure(User) { User.all(:conditions => {:profile_id => self.id}) }
          errors.add('is_profile', _('Cannot be removed (profile used).'))
        end
      end
      
      if @profile_error
        errors.add(:profile_id, @profile_error)
        remove_instance_variable :@profile_error
      end
      
      if @password_too_short
        errors.add(:password, _('Too short'))
        remove_instance_variable :@password_too_short
      end
      
      if @defined_group_ids_error
        errors.add(:group_ids, _('Only admin can change groups.'))
        remove_instance_variable :@defined_group_ids_error
      end
    end

    def valid_node
      return unless visitor.site[:root_id] # do not validate node if the root node is not created yet

      return if (!new_record? || self[:node_id]) && !@node
      if !@node
        # force creation of node, even if it is a plain copy of the prototype
        self.node_attributes = {'title' => login}
      else
        @node.title ||= login
      end

      if @node.valid?
        # ok
      else
        @node.errors.each_error do |err, msg|
          errors.add("node[#{err}]", msg)
        end
      end
    end

    # Make sure all users are in the _public_ and _site_ groups. Make sure
    # the user only belongs to groups in the same site.
    def valid_groups #:doc:
      g_ids = @defined_group_ids || (new_record? ? [] : group_set_ids)
      g_ids.reject! { |g| g.blank? }
      g_ids << site.public_group_id
      g_ids << site.site_group_id unless is_anon?
      g_ids.uniq!
      g_ids.compact!
      self.groups = []
      g_ids.each do |id|
        group = Group.find(:first, :conditions => {:id => id})
        unless group && (group.site_id == self.site_id || site.being_created?)
          errors.add('group', 'not found')
          next
        end
        self.groups << group
      end
    end

    # Do not allow destruction of the site's special users.
    def dont_destroy_protected_users #:doc:
      raise Zena::AccessViolation, "su and Anonymous users cannot be destroyed !" if site.protected_user_ids.include?(id)
    end

    def old
      @old ||= self.class.find(self[:id])
    end
    
    def user_after_save
      @node.save if @node
      return unless is_profile?
      
      if users = secure(User) { User.all(:conditions => {:profile_id => self.id}) }
        users.each do |u|
          u.save # this will trigger sync
        end
      end
      true
    end
end
