=begin rdoc
A zena installation supports many sites. Each site is uniquely identified by it's host name.
The #Site model holds configuration information for a site:

+host+::            Unique host name. (teti.ch, zenadmin.org, dev.example.org, ...)
+root_id+::         Site root node id. This is the only node in the site without a parent.
+su_id+::           Super User id. This user has extended priviledges on the site. It should only be used in case of emergency.
+anon_id+::         Anonymous user id. This user is the 'public' user of the site. Even if +authorize+ is set to true, this user is needed to configure the defaults for all newly created users.
+public_group_id+:: Id of the 'public' group. Every user of the site (with 'anonymous user') belongs to this group.
+site_group_id+::   Id of the 'site' group. Every user except anonymous are part of this group. This group can be seen as the 'logged in users' group.
+name+::            Site name (used to display grouped information for cross sites users).
+authorize+::       If this is set to true a login is required: anonymous visitor will not be allowed to browse the site as there is no login/password for the 'anonymous user'.
+monolingual+::     Only use the +default_lang+. This will disable the language selection menu and will remove the language prefix from all urls.
+allow_private+::   If set to true, users will be allowed to create private nodes (seen only by themselves).
+languages+::       A comma separated list of the languages used for the current site. Do not insert spaces in this list.
+default_lang+::    The default language of the site (or the unique language if +monolingual+ is true).
=end
class Site < ActiveRecord::Base
  validate :valid_site
  validates_uniqueness_of :host
  attr_accessible :name, :languages, :default_lang, :authentication, :monolingual, :allow_private, :http_auth
  has_many :groups, :order => "name"
  has_many :nodes
  has_many :participations, :dependent => :destroy
  has_many :users, :through => :participations
  
  class << self
    
    # Create a new site in the database. This should not be called directly. Use
    # +rake zena:mksite HOST=[host_name]+ instead
    def create_for_host(host, su_password, opts={})
      params = {
        :name            => host.split('.').first,
        :authentication  => false,
        :monolingual     => false,
        :allow_private   => false,
        :languages       => '',
        :default_lang    => "en",
      }.merge(opts)
      langs = params[:languages].split('.')
      langs += [params[:default_lang]] unless langs.include?(params[:default_lang])
      params[:languages] = langs.map{|l| l[0..1]}.join(',')
      params[:default_lang] = params[:default_lang][0..1]
      
      
      site      = self.new(params)
      site.host = host
      site.save
      site.instance_variable_set(:@being_created, true)
      
      if site.new_record?
        return site
      end
      
      # =========== CREATE zip counter ==========================
      connection.execute "INSERT INTO zips (site_id, zip) VALUES (#{site[:id]},0)"
      
      # =========== CREATE Super User ===========================
      # create su user
      su = User.new_no_defaults( :login => host, :password => su_password,
        :first_name => "Super", :name => "User", :lang=>site.default_lang)
      su.site = site
                                
      raise Exception.new("Could not create super user for site [#{host}] (site#{site[:id]})\n#{su.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") unless su.save
      
      site[:su_id] = su[:id]
      unless Thread.current.respond_to?(:visitor)
        class << Thread.current
          attr_accessor :visitor
        end
      end
      Thread.current.visitor = su
      
      # =========== CREATE PUBLIC, ADMIN, SITE GROUPS ===========
      # create public group
      pub = site.send(:secure,Group) { Group.create(:name => 'public') }
      raise Exception.new("Could not create public group for site [#{host}] (site#{site[:id]})\n#{pub.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") if pub.new_record?
      
      # create admin group
      admin = site.send(:secure,Group) { Group.create( :name => 'admin') }
      raise Exception.new("Could not create group for site [#{host}] (site#{site[:id]})\n#{admin.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") if admin.new_record?
      
      # create site group
      sgroup = site.send(:secure,Group) { Group.create( :name => site.name) }
      raise Exception.new("Could not create group for site [#{host}] (site#{site[:id]})\n#{sgroup.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") if sgroup.new_record?
      
      site.public_group_id = pub[:id]
      site.site_group_id   = sgroup[:id]
      site.groups << pub << sgroup << admin
      
      # =========== CREATE Anonymous, admin =====================
      # create anon user
      # FIXME: make sure user_id = admin user
      anon = site.send(:secure,User) { User.new_no_defaults( :login => nil, :password => nil,
        :first_name => "Anonymous", :name => "User", :lang=>site.default_lang) }
      anon.site = site
      raise Exception.new("Could not create anonymous user for site [#{host}] (site#{site[:id]})\n#{anon.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") unless anon.save
      site[:anon_id] = anon[:id]
      
      # create admin user
      admin_user = site.send(:secure,User) { User.new_no_defaults( :login => 'admin', :password => su_password,
        :first_name => "Admin", :name => "User", :lang=>site.default_lang) }
      admin_user.site = site
      raise Exception.new("Could not create admin user for site [#{host}] (site#{site[:id]})\n#{admin_user.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") unless admin_user.save
      class << admin_user
        # until participation is created
        def status; User::Status[:admin]; end
      end
      # add admin to the 'admin group'
      admin.users << admin_user
      
      # =========== CREATE ROOT NODE ============================
      # reload admin so all groups are set
      
      #admin_user = site.send(:secure, User) { User.find(admin_user[:id]) }
      
      # make admin the current visitor
      Thread.current.visitor = admin_user
      
      root = site.send(:secure,Project) { Project.create( :name => site.name, :rgroup_id => pub[:id], :wgroup_id => sgroup[:id], :pgroup_id => admin[:id], :v_title => site.name) }
      raise Exception.new("Could not create root node for site [#{host}] (site#{site[:id]})\n#{root.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") if root.new_record?
      
      Node.connection.execute "UPDATE nodes SET section_id = id, project_id = id WHERE id = '#{root[:id]}'"
      
      raise Exception.new("Could not publish root node for site [#{host}] (site#{site[:id]})\n#{root.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") unless root.publish
      
      site.root_id         = root[:id]
      
      # =========== UPDATE SITE =================================
      # save site definition
      raise Exception.new("Could not save site definition for site [#{host}] (site#{site[:id]})\n#{site.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") unless site.save
      
      # =========== CREATE PARTICIPATIONS FOR USERS ==============
      [[su, :su], [anon, :moderated], [admin_user, :admin]].each do |user,status| 
        raise Exception.new("Could not create participation to site #{site[:id]} for user #{user[:id]} (#{status})") unless Participation.new( :user => user, :site => site, :status => User::Status[status]).save
      end
      
      # =========== LOAD INITIAL DATA (default skin) =============
      
      nodes = site.send(:secure,Node) { Node.create_nodes_from_folder(:folder => File.join(RAILS_ROOT, 'db', 'init', 'base'), :parent_id => root[:id], :defaults => { :v_status => Zena::Status[:pub], :rgroup_id => pub[:id], :wgroup_id => sgroup[:id], :pgroup_id => admin[:id] } ) }
      puts nodes.map { |n| [n.name,n.v_status,n.max_status]}.inspect # FIXME: MAX_STATUS NOT UPDATED !!!
      
      
      site_skin = site.send(:secure, Skin) { Skin.find_by_name('site') }
      
      site_skin.update_attributes( :name => site.name, :v_title => "#{site.name} skin" )
      
      # == set skin name for all elements in the site but the templates == #
      Node.connection.execute "UPDATE nodes SET skin = '#{site.name}' WHERE site_id = '#{site[:id]}' AND section_id <> '#{site_skin.parent_id}'"
      Node.connection.execute "UPDATE nodes SET skin = 'default' WHERE site_id = '#{site[:id]}' AND section_id = '#{site_skin.parent_id}'"
      
      
      # == done.
      Site.logger.info "=========================================================="
      Site.logger.info "  NEW SITE CREATED FOR [#{host}] (site#{site[:id]})"
      Site.logger.info "=========================================================="
      
      site.instance_variable_set(:@being_created, false)
      site
    end
  end
  
  # Return path for static/cached content served by proxy: RAILS_ROOT/sites/_host_/public
  # If you need to serve from another directory, we do not store the path into the sites table
  # for security reasons. The easiest way around this limitation is to symlink the 'public' directory.
  def public_path
    "/#{self[:host]}/public"
  end
  
  # Return path for documents data: RAILS_ROOT/sites/_host_/data
  # You can symlink the 'data' directory if you need to keep the data in some other place.
  def data_path
    "/#{self[:host]}/data"
  end
  
  # Return the path for zafu rendered templates: RAILS_ROOT/sites/_host_/zafu
  def zafu_path
    "/#{self[:host]}/zafu"
  end
  
  # Return the anonymous user, the one used by anonymous visitors to visit the public part
  # of the site.
  def anon
    @anon ||= secure(User) { User.find(self[:anon_id]) }
  end
  
  # Return the super user. This user has extended priviledges on the data (has access to private other's data).
  # This is an emergency user.
  def su
    @su ||= secure(User) { User.find(self[:su_id]) }
  end
  
  # TODO: test
  def root_node
    secure(Node) { Node.find(self[:root_id]) }
  end
  
  # Return the public group: the one in which every visitor belongs.
  def public_group
    @public_group ||= Group.find(self[:public_group_id])
  end
  
  # Return the site group: the one in which every visitor except 'anonymous' belongs (= all logged in users).
  def site_group
    @site_group ||= Group.find(self[:site_group_id])
  end

  # Return true if the given user is an administrator for this site.
  def is_admin?(user)
    admin_user_ids.include?(user[:id])
  end
  
  # Return the ids of the administrators of the current site.
  def admin_user_ids
    # TODO: admin_user_ids could be cached in the 'site' record.
    @admin_user_ids ||= secure(User) { User.find(:all, :conditions => "status >= #{User::Status[:admin]}") }.map {|r| r[:id]}
  end
  
  # Return true if the site is configured to use a single language
  def monolingual?
    self[:monolingual]
  end
  
  # Return true if the site is configured to allow private nodes
  def allow_private?
    self[:allow_private]
  end
  
  # Return true if the site is configured to force authentication
  def authentication?
    self[:authentication]
  end
  
  # ids of the groups that cannot be removed
  def protected_group_ids
    [site_group_id, public_group_id]
  end
  
  # ids of the users that cannot be removed
  def protected_user_ids
    [anon_id, su_id]
  end
  
  # Return an array with the languages for the site.
  def lang_list
    (self[:languages] || "").split(',').map(&:strip)
  end
  
  def being_created?
    @being_created
  end
  
  def languages=(s)
    self[:languages] = s.split(',').map(&:strip).join(',')
  end
  
  private
    def valid_site
      errors.add(:host, "invalid host name #{self[:host].inspect}") if self[:host].nil? || (self[:host] =~ /^\./) || (self[:host] =~ /[^\w\.\-]/)
      errors.add(:languages, "invalid languages") unless self[:languages].split(',').inject(true){|i,l| (i && l =~ /^\w\w$/)}
      errors.add(:default_lang, "invalid default language") unless self[:languages].split(',').include?(self[:default_lang])
    end
end
