=begin rdoc
A zena installation supports many sites. Each site is uniquely identified by it's host name.
The #Site model holds configuration information for a site:

+host+::            Unique host name. (teti.ch, zenadmin.org, dev.example.org, ...)
+root_id+::         Site root node id. This is the only node in the site without a parent.
+su_id+::           Super User id. This user has extended priviledges on the site. It should only be used in case of emergency.
+anon_id+::         Anonymous user id. This user is the 'public' user of the site. Even if +authorize+ is set to true, this user is needed to configure the defaults for all newly created users.
+public_group_id+:: Id of the 'public' group. Every user of the site (with 'anonymous user') belongs to this group.
+admin_group_id+::  Users in this group automatically belong to all other groups. These users can change site settings and manage users.
+site_group_id+::   Id of the 'site' group. Every user except anonymous are part of this group. This group can be seen as the 'logged in users' group.
+trans_group_id+::  Interface translators' group. People in this group can edit the interface translations.
+name+::            Site name (used to display grouped information for cross sites users).
+authorize+::       If this is set to true a login is required: anonymous visitor will not be allowed to browse the site as there is no login/password for the 'anonymous user'.
+monolingual+::     Only use the +default_lang+. This will disable the language selection menu and will remove the language prefix from all urls.
+allow_private+::   If set to true, users will be allowed to create private nodes (seen only by themselves).
+languages+::       A comma separated list of the languages used for the current site. Do not insert spaces in this list.
+default_lang+::    The default language of the site (or the unique language if +monolingual+ is true).
=end
class Site < ActiveRecord::Base
  validates_uniqueness_of :host
  attr_accessible :name, :authorize, :monolingual, :allow_private, :languages, :default_lang, :admin_group_id, :trans_group_id, :site_group_id
  has_many :groups, :order=>"name"
  has_many :nodes
  has_and_belongs_to_many :users
  
  class << self
    
    # Create a new site in the database. This should not be called directly. Use
    # +rake zena:mksite HOST=[host_name]+ instead
    def create_for_host(host, su_password)
      site = self.new
      site.host            = host
      site.name            = host.split('.').first
      site.authorize       = false
      site.monolingual     = false
      site.allow_private   = false
      site.languages       = "en"
      site.default_lang    = "en"
      site.save
      
      if site.new_record?
        return site
      end
      
      # =========== CREATE zip counter ==========================
      connection.execute "INSERT INTO zips (site_id, zip) VALUES (#{site[:id]},0)"
      
      # =========== CREATE Super User ===========================
      # create su user
      su = User.new_no_defaults( :login => host, :password => su_password,
        :first_name => "Super", :name => "User", :lang=>'en')
      su.site    = site
      su.visit(su)
      raise Exception.new("Could not create super user for site [#{host}] (site#{site[:id]})\n#{su.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") unless su.save
      su.visit(site) # su is visitor
      site.su_id           = su[:id]
      
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
      site.admin_group_id  = admin[:id]
      site.trans_group_id  = admin[:id]
      site.site_group_id   = sgroup[:id]
      site.groups << pub << sgroup << admin
      
      # =========== CREATE Anonymous, admin =====================
      # create anon user
      anon = site.send(:secure,User) { User.new_no_defaults( :login => nil, :password => nil,
        :first_name => "Anonymous", :name => "User", :lang=>'en', :status=>User::Status[:moderated]) }
      raise Exception.new("Could not create anonymous user for site [#{host}] (site#{site[:id]})\n#{anon.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") unless anon.save
      
      # create admin user
      admin_user = site.send(:secure,User) {User.new_no_defaults( :login => 'admin', :password => su_password,
        :first_name => "Admin", :name => "User", :lang=>'en') }
      raise Exception.new("Could not create admin user for site [#{host}] (site#{site[:id]})\n#{admin_user.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") unless admin_user.save
      
      site.anon_id         = anon[:id]
      
      # add all users to this site
      site.users << su
      site.users << admin_user
      site.users << anon
      
      # add anon and admin to 'public group'
      pub.users << anon
      pub.users << admin_user
      raise Exception.new("Could not add anon and admin users to public group for site [#{host}] (site#{site[:id]})\n#{pub.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") unless pub.save
      
      # add admin to the 'site group'
      sgroup.users << admin_user
      raise Exception.new("Could not add admin user to site group for site [#{host}] (site#{site[:id]})\n#{sgroup.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") unless sgroup.save
      
      # add admin to the 'admin group'
      admin.users << admin_user
      raise Exception.new("Could not add admin user to admin group for site [#{host}] (site#{site[:id]})\n#{admin.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") unless admin.save
      
      
      # =========== CREATE ROOT NODE ============================
      # reload admin so all groups are set
      
      admin_user = site.send(:secure, User) { User.find(admin_user[:id]) }
      admin_user.site = site
      admin_user.visit(site) # now admin is the 'visitor' for 'site'
      root = site.send(:secure,Project) { Project.create( :name => site.name, :rgroup_id => pub[:id], :wgroup_id => sgroup[:id], :pgroup_id => admin[:id], :v_title => site.name) }
      raise Exception.new("Could not create root node for site [#{host}] (site#{site[:id]})\n#{root.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") if root.new_record?
      
      raise Exception.new("Could not publish root node for site [#{host}] (site#{site[:id]})\n#{root.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") unless root.publish
      
      site.root_id         = root[:id]
      
      # =========== UPDATE SITE =================================
      # save site definition
      raise Exception.new("Could not save site definition for site [#{host}] (site#{site[:id]})\n#{site.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") unless site.save
      
      # =========== LOAD DEFAULT TRANSLATIONS ===================
      Site.logger.info "=========================================================="
      Site.logger.info "  NEW SITE CREATED FOR [#{host}] (site#{site[:id]})"
      Site.logger.info "=========================================================="
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
  
  # Return the anonymous user, the one used by anonymous visitors to visit the public part
  # of the site.
  def anon
    @anon ||= returning(User.find(self[:anon_id])) {|user| user.site = self}
  end
  
  # Return the super user. This user has extended priviledges on the data (has access to private other's data).
  # This is an emergency user.
  def su
    @su ||= returning(User.find(self[:su_id])) {|user| user.site = self}
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
    @admin_user_ids ||= admin_group.user_ids
  end
  
  # Return the admin group: any user in this group automatically belongs in all other groups from the site.
  def admin_group
    @admin_group ||= Group.find(self[:admin_group_id])
  end
  
  # ids of the groups that cannot be removed
  def protected_group_ids
    [admin_group_id, site_group_id, public_group_id]
  end
  
  # ids of the users that cannot be removed
  def protected_user_ids
    [anon_id, su_id]
  end
  
  # Return an array with the languages for the site.
  def lang_list
    (self[:languages] || "").split(',').map(&:strip)
  end
end
