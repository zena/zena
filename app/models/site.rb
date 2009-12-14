# make sure tehse two libraries are loaded or mksite rake task will fail.
require 'zena/use/dates'

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
+languages+::       A comma separated list of the languages used for the current site. Do not insert spaces in this list.
+default_lang+::    The default language of the site.
=end
class Site < ActiveRecord::Base
  include RubyLess::SafeClass
  safe_method :host => String

  validate :valid_site
  validates_uniqueness_of :host
  attr_accessible :dyn_attributes, :name, :languages, :default_lang, :authentication, :http_auth, :auto_publish, :redit_time
  has_many :groups, :order => "name"
  has_many :nodes
  has_many :users

  include Zena::Use::DynAttributes::ModelMethods
  dynamic_attributes_setup :table_name => 'site_attributes', :nested_alias => {%r{^d_(\w+)} => ['dyn']}

  @@attributes_for_form = {
    :bool => [:authentication, :http_auth, :auto_publish],
    :text => [:name, :languages, :default_lang],
  }

  class << self

    # Create a new site in the database. This should not be called directly. Use
    # +rake zena:mksite HOST=[host_name]+ instead
    def create_for_host(host, su_password, opts={})
      params = {
        :name            => host.split('.').first,
        :authentication  => false,
        :auto_publish    => false,
        :redit_time      => '2h',
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
        :first_name => "Super", :name => "User", :lang => site.default_lang, :status => User::Status[:su])
      su.site = site

      Thread.current[:visitor] = su

      unless su.save
        # rollback
        Site.connection.execute "DELETE FROM #{Site.table_name} WHERE id = #{site.id}"
        Site.connection.execute "DELETE FROM zips WHERE site_id = #{site.id}"
        raise Exception.new("Could not create super user for site [#{host}] (site#{site[:id]})\n#{su.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}")
      end

      site[:su_id] = su[:id]


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

      anon = site.send(:secure, User) {User.new_no_defaults( :login => nil, :password => nil,
        :first_name => "Anonymous", :name => "User", :lang => site.default_lang, :status => User::Status[:moderated])}

      anon.site = site
      raise Exception.new("Could not create anonymous user for site [#{host}] (site#{site[:id]})\n#{anon.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") unless anon.save
      site[:anon_id] = anon[:id]

      # create admin user
      admin_user = site.send(:secure,User) { User.new_no_defaults( :login => 'admin', :password => su_password,
        :first_name => "Admin", :name => "User", :lang => site.default_lang, :status => User::Status[:admin]) }
      admin_user.site = site
      raise Exception.new("Could not create admin user for site [#{host}] (site#{site[:id]})\n#{admin_user.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") unless admin_user.save
      class << admin_user
        # until participation is created
        def status; User::Status[:admin]; end
        def lang; site.default_lang; end
      end
      # add admin to the 'admin group'
      admin.users << admin_user

      # =========== CREATE ROOT NODE ============================
      # reload admin so all groups are set

      #admin_user = site.send(:secure, User) { User.find(admin_user[:id]) }

      # make admin the current visitor
      Thread.current[:visitor] = admin_user

      root = site.send(:secure,Project) { Project.create( :name => site.name, :rgroup_id => pub[:id], :wgroup_id => sgroup[:id], :dgroup_id => admin[:id], :v_title => site.name, :v_status => Zena::Status[:pub]) }
      raise Exception.new("Could not create root node for site [#{host}] (site#{site[:id]})\n#{root.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") if root.new_record?

      Node.connection.execute "UPDATE nodes SET section_id = id, project_id = id WHERE id = '#{root[:id]}'"

      raise Exception.new("Could not publish root node for site [#{host}] (site#{site[:id]})\n#{root.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") unless (root.v_status == Zena::Status[:pub] || root.publish)

      site.root_id = root[:id]

      # =========== UPDATE SITE =================================
      # save site definition
      raise Exception.new("Could not save site definition for site [#{host}] (site#{site[:id]})\n#{site.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") unless site.save

      # =========== CREATE CONTACT PAGES ==============
      [su, admin_user, anon].each do |user|
        user.send(:create_contact)
        user.save
      end

      # =========== LOAD INITIAL DATA (default skin) =============

      nodes = site.send(:secure,Node) { Node.create_nodes_from_folder(:folder => File.join(Zena::ROOT, 'db', 'init', 'base'), :parent_id => root[:id], :defaults => { :v_status => Zena::Status[:pub], :rgroup_id => pub[:id], :wgroup_id => sgroup[:id], :dgroup_id => admin[:id] } ) }.values

      # == set skin name to 'default' for all elements in the site == #
      Node.connection.execute "UPDATE nodes SET skin = 'default' WHERE site_id = '#{site[:id]}'"


      # == done.
      Site.logger.info "=========================================================="
      Site.logger.info "  NEW SITE CREATED FOR [#{host}] (site#{site[:id]})"
      Site.logger.info "=========================================================="

      site.instance_variable_set(:@being_created, false)
      site
    end

    def find_by_host(host)
      host = $1 if host =~ /^(.*)\.$/
      self.find(:first, :conditions => ['host = ?', host]) rescue nil
    end

    # List of attributes that can be configured in the admin form
    def attributes_for_form
      @@attributes_for_form
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
    @anon ||= User.find_by_id_and_site_id(self[:anon_id], self.id)
  end

  # Return the super user. This user has extended priviledges on the data (has access to private other's data).
  # This is an emergency user.
  def su
    @su ||= User.find_by_id_and_site_id(self[:su_id], self.id)
  end

  # TODO: test
  def root_node
    secure!(Node) { Node.find(self[:root_id]) }
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
    @admin_user_ids ||= secure!(User) { User.find(:all, :conditions => "status >= #{User::Status[:admin]}") }.map {|r| r[:id]}
  end

  # Return true if the site is configured to force authentication
  def authentication?
    self[:authentication]
  end

  # Return true if the site is configured to automatically publish redactions
  def auto_publish?
    self[:auto_publish]
  end

  # Set redit time from a string of the form "1d 4h 5s" or "4 days"
  def redit_time=(val)
    if val.kind_of?(String)
      self[:redit_time] = val.to_duration
    else
      self[:redit_time] = val
    end
  end

  # Return the time between version updates below which no new version is created. This returns a string of
  # the form "3 hours 45 minutes"
  def redit_time
    (self[:redit_time] || 0).as_duration
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

  def iformats
   @iformats ||= begin
     $iformats ||= {} # mem cache
     site_formats = $iformats[self[:id]]
     if !site_formats || self[:formats_updated_at] != site_formats[:updated_at]
       site_formats = $iformats[self[:id]] = Iformat.formats_for_site(self[:id]) # reload
     end
     site_formats
    end
  end

  def iformats_updated!
    Site.connection.execute "UPDATE sites SET formats_updated_at = (SELECT updated_at FROM iformats WHERE site_id = #{self[:id]} ORDER BY iformats.updated_at DESC LIMIT 1) WHERE id = #{self[:id]}"
    if $iformats
      $iformats[self[:id]] = @iformats = nil
    end
  end

  def clear_cache(clear_zafu = true)
    path = "#{SITES_ROOT}#{self.public_path}"
    Site.logger.error("\n-----------------\nCLEAR CACHE FOR SITE #{host}\n-----------------\n")

    if File.exist?(path)
      Dir.foreach(path) do |elem|
        next unless elem =~ /^(\w\w\.html|\w\w|login\.html)$/
        FileUtils.rmtree(File.join(path, elem))
      end

      Site.connection.execute "DELETE FROM caches WHERE site_id = #{self[:id]}"
      Site.connection.execute "DELETE FROM cached_pages_nodes WHERE cached_pages_nodes.node_id IN (SELECT nodes.id FROM nodes WHERE nodes.site_id = #{self[:id]})"
      Site.connection.execute "DELETE FROM cached_pages WHERE site_id = #{self[:id]}"
      Node.connection.execute "UPDATE nodes SET fullpath = NULL, basepath = NULL WHERE site_id = #{self[:id]}"
    end

    if clear_zafu
      path = "#{SITES_ROOT}#{self.zafu_path}"
      if File.exist?(path)
        FileUtils.rmtree(path)
      end
    end
  end

  def rebuild_vhash
    lang_list = self.lang_list.sort
    i = 0
    while true
      nodes = Node.find(:all, :conditions => ['site_id = ?', id], :order=>'id ASC', :limit => 50, :offset => i * 50)
      break if nodes.empty?
      nodes.each do |node|
        node.rebuild_vhash
        Node.connection.execute "UPDATE nodes SET publish_from = #{Node.connection.quote(node.publish_from)}, vhash = #{Node.connection.quote(node.vhash.to_json)} WHERE id = #{node.id}"
      end
      # 50 more
      i += 1
    end
  end

  def rebuild_fullpath(parent_id = nil, parent_fullpath = "", parent_basepath = "")
    i = 0
    batch_size = 100
    children = []
    while true
      rec = Zena::Db.fetch_attributes(['id', 'fullpath', 'basepath', 'custom_base', 'name'], 'nodes', "parent_id #{parent_id ? "= #{parent_id}" : "IS NULL"} AND site_id = #{self.id} ORDER BY id ASC LIMIT #{batch_size} OFFSET #{i * batch_size}")
      break if rec.empty?
      rec.each do |rec|
        if parent_id
          rec['fullpath'] = parent_fullpath == '' ? rec['name'] : "#{parent_fullpath}/#{rec['name']}"
        else
          # root node
          rec['fullpath'] = ''
        end

        if rec['custom_base'].to_i == 1
          rec['basepath'] = rec['fullpath']
        else
          rec['basepath'] = parent_basepath
        end

        id = rec.delete('id')
        children << [id, rec['fullpath'], rec['basepath']]
        Zena::Db.execute "UPDATE nodes SET #{rec.map {|k,v| "#{Zena::Db.connection.quote_column_name(k)}=#{Zena::Db.quote(v)}"}.join(', ')} WHERE id = #{id}"
      end
      # 50 more
      i += 1
    end
    children.each do |child|
      rebuild_fullpath(*child)
    end
  end

  private
    def valid_site
      errors.add(:host, 'invalid') if self[:host].nil? || (self[:host] =~ /^\./) || (self[:host] =~ /[^\w\.\-]/)
      errors.add(:languages, 'invalid') unless self[:languages].split(',').inject(true){|i,l| (i && l =~ /^\w\w$/)}
      errors.add(:default_lang, 'invalid') unless self[:languages].split(',').include?(self[:default_lang])
    end
end

Bricks.apply_patches