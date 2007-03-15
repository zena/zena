class Site < ActiveRecord::Base
  validates_uniqueness_of :host
  attr_protected :host, :su_id, :anon_id, :root_id
  has_many :groups, :order=>"name"
  has_many :nodes
  has_and_belongs_to_many :users
  acts_as_secure
  
  class << self
    
    # Create a new site in the database. This should not be called directly. Use
    # rake zena:mksite HOST=[host_name] instead
    # TODO: test !
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
      
      # =========== CREATE SU, ANON, ADMIN USERS ================
      # create su user
      su = User.new( :login => host, :password => su_password,
        :first_name => "Super", :name => "User", :lang=>'en')
      su.site    = site
      raise Exception.new("Could not create super user for site [#{host}] (site#{site[:id]})\n#{su.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") unless su.save
      su.visit(site) # su is visitor
      
      # create anon user
      anon = site.send(:secure,User) { User.create( :login => nil, :password => nil,
        :first_name => "Anonymous", :name => "User", :lang=>'en') }
      raise Exception.new("Could not create anonymous user for site [#{host}] (site#{site[:id]})\n#{anon.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") if anon.new_record?
      
      # create admin user
      admin_user = site.send(:secure,User) {User.create( :login => 'admin', :password => su_password,
        :first_name => "Admin", :name => "User", :lang=>'en') }
      raise Exception.new("Could not create admin user for site [#{host}] (site#{site[:id]})\n#{admin_user.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") if admin_user.new_record?
      
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
      
      
      # =========== ADD USERS TO GROUPS =========================
      site.anon_id         = anon[:id]
      site.public_group_id = pub[:id]
      site.su_id           = su[:id]
      site.admin_group_id  = admin[:id]
      site.trans_group_id  = admin[:id]
      site.site_group_id   = sgroup[:id]
      
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
  
  # Anonymous user, the one used by anonymous visitors to visit the public part
  # of the site.
  def anon
    @anon ||= User.find(self[:anon_id])
  end
  
  # Super user: has extended priviledges on the data (has access to private data)
  def su
    @su ||= User.find(self[:su_id])
  end
  
  # Public group, the one in which every visitor belongs.
  def public_group
    @pub ||= Group.find(self[:public_group_id])
  end
  
  # Site group, the one in which every visitor except 'anonymous' belongs (= all logged in users).
  def site_group
    @pub ||= Group.find(self[:site_group_id])
  end
  
  # Admin group: any user in this group automatically belongs in all other groups from the site.
  def admin_group
    @adm ||= Group.find(self[:admin_group_id])
  end
  
  # ids of the groups that cannot be removed
  def protected_group_ids
    [admin_group_id, site_group_id, public_group_id]
  end
  
  # ids of the users that cannot be removed
  def protected_user_ids
    [anon_id, su_id]
  end
end
