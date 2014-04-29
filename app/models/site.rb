# make sure tehse two libraries are loaded or mksite rake task will fail.
require 'zena/use/dates'

=begin rdoc
A zena installation supports many sites. Each site is uniquely identified by it's host name.
The #Site model holds configuration information for a site:

+host+::            Unique host name. (teti.ch, zenadmin.org, dev.example.org, ...)
+root_id+::         Site seed node id. This is the only node in the site without a parent.
+home_id+::         This is the apparent root of the site (home page).
+anon_id+::         Anonymous user id. This user is the 'public' user of the site. Even if +authorize+ is set to true, this user is needed to configure the defaults for all newly created users.
+public_group_id+:: Id of the 'public' group. Every user of the site (with 'anonymous user') belongs to this group.
+site_group_id+::   Id of the 'site' group. Every user except anonymous are part of this group. This group can be seen as the 'logged in users' group.
+name+::            Site name (used to display grouped information for cross sites users).
+authorize+::       If this is set to true a login is required: anonymous visitor will not be allowed to browse the site as there is no login/password for the 'anonymous user'.
+languages+::       A comma separated list of the languages used for the current site. Do not insert spaces in this list.
+default_lang+::    The default language of the site.
=end
class Site < ActiveRecord::Base
  attr_accessor :alias # = site alias (different settings + domain)
  CLEANUP_SQL = [
    ['attachments'         , 'site_id = ?'],
    ['cached_pages'        , 'site_id = ?'],
    ['cached_pages_nodes'  , 'node_id IN (SELECT id FROM nodes WHERE site_id = ?)'],
    ['caches'              , 'site_id = ?'],
    ['columns'             , 'site_id = ?'],
    ['comments'            , 'site_id = ?'],
    ['data_entries'        , 'site_id = ?'],
    ['discussions'         , 'site_id = ?'],
    ['groups_users'        , 'group_id IN (SELECT id FROM groups WHERE site_id = ?)'],
    ['groups'              , 'site_id = ?'],

    ['idx_nodes_datetimes' , 'node_id IN (SELECT id FROM nodes WHERE site_id = ?)'],
    ['idx_nodes_floats'    , 'node_id IN (SELECT id FROM nodes WHERE site_id = ?)'],
    ['idx_nodes_integers'  , 'node_id IN (SELECT id FROM nodes WHERE site_id = ?)'],
    ['idx_nodes_ml_strings', 'node_id IN (SELECT id FROM nodes WHERE site_id = ?)'],
    ['idx_nodes_strings'   , 'node_id IN (SELECT id FROM nodes WHERE site_id = ?)'],
    ['idx_projects'        , 'node_id IN (SELECT id FROM nodes WHERE site_id = ?)'],
    ['idx_templates'       , 'node_id IN (SELECT id FROM nodes WHERE site_id = ?)'],

    ['iformats'            , 'site_id = ?'],
    ['links'               , 'source_id IN (SELECT id FROM nodes WHERE site_id = ?)'],
    ['links'               , 'target_id IN (SELECT id FROM nodes WHERE site_id = ?)'],

    ['nodes_roles'         , 'node_id IN (SELECT id FROM nodes WHERE site_id = ?)'],
    ['relations'           , 'site_id = ?'],
    ['roles'               , 'site_id = ?'],
    ['sites'               , 'id = ?'],
    ['users'               , 'site_id = ?'],
    ['versions'            , 'site_id = ?'],
    ['zips'                , 'site_id = ?'],
    ['nodes'               , 'site_id = ?'],
  ]
  ACTIONS = %w{clear_cache rebuild_index rebuild_fullpath}
  PUBLIC_PATH = Bricks.raw_config['public_path'] || '/public'
  CACHE_PATH  = Bricks.raw_config['cache_path']  || '/public'
  
  include RubyLess
  safe_method  :host   => String, :lang_list => [String], :default_lang => String, :master_host => String
  safe_method  :root   => Proc.new {|h, r, s| {:method => 'root_node', :class => current_site.root_node.vclass, :nil => true}}
  safe_method  :home   => Proc.new {|h, r, s| {:method => 'home_node', :class => current_site.home_node.vclass, :nil => true}}

  validate :valid_site
  validates_uniqueness_of :host
  attr_accessible :name, :languages, :default_lang, :authentication, :http_auth, :ssl_on_auth, :auto_publish, :redit_time, :api_group_id, :home_zip, :skin_zip
  has_many :groups, :order => "name"
  has_many :nodes
  has_many :users

  include Property

  # Should be the same serialization as in Node
  include Property::Serialization::JSON

  # TODO: can we just use MLIndex in app.rb ?
  include Zena::Use::MLIndex::SiteMethods

  @@attributes_for_form = {
    :bool => %w{authentication http_auth auto_publish ssl_on_auth},
    :text => %w{languages default_lang},
  }
  
  @@alias_attributes_for_form = {
    :bool => %w{authentication auto_publish ssl_on_auth},
    :text => %w{},
  }

  class << self

    # Create a new site in the database. This should not be called directly. Use
    # +rake zena:mksite HOST=[host_name]+ instead
    def create_for_host(host, su_password, opts={})
      params = {
        :name                      => host.split('.').first,
        :authentication            => false,
        :auto_publish              => true,
        :redit_time                => '2h',
        :languages                 => '',
        :default_lang              => "en",
        :usr_prototype_attributes  => "{'klass' => 'Contact'}"
      }.merge(opts)
      langs = params[:languages].split(',').map(&:strip)
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

      # =========== CREATE Admin User ===========================

      # create admin user
      admin_user = User.new_no_defaults(
        :login => 'admin',           :password => su_password,
        :lang  => site.default_lang, :status => User::Status[:admin])
      admin_user.site = site

      setup_visitor(admin_user, site)

      unless admin_user.save
        # rollback
        Zena::Db.execute "DELETE FROM #{Site.table_name} WHERE id = #{site.id}"
        Zena::Db.execute "DELETE FROM zips WHERE site_id = #{site.id}"
        raise Exception.new("Could not create admin user for site [#{host}] (site#{site[:id]})\n#{admin_user.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}")
      end

      # =========== CREATE PUBLIC, ADMIN, SITE GROUPS ===========
      # create public group
      pub = site.send(:secure,Group) { Group.create(:name => 'public') }
      raise Exception.new("Could not create public group for site [#{host}] (site#{site[:id]})\n#{pub.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") if pub.new_record?

      # create admin group
      editors = site.send(:secure,Group) { Group.create( :name => 'editors') }
      raise Exception.new("Could not create editors group for site [#{host}] (site#{site[:id]})\n#{editors.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") if editors.new_record?

      # add admin to the 'editors group'
      editors.users << admin_user

      # create site group
      sgroup = site.send(:secure,Group) { Group.create( :name => 'logged-in') }
      raise Exception.new("Could not create logged-in group for site [#{host}] (site#{site[:id]})\n#{sgroup.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") if sgroup.new_record?

      site.public_group_id = pub[:id]
      site.site_group_id   = sgroup[:id]
      site.groups << pub << sgroup << editors

      # Reload group_ids in admin
      admin_user.reload_groups!

      # =========== CREATE Anonymous User =====================
      # create anon user

      anon = site.send(:secure, User) do
        User.new_no_defaults( :login => nil, :password => nil,
        :lang => site.default_lang, :status => User::Status[:moderated])
      end

      anon.site = site
      raise Exception.new("Could not create anonymous user for site [#{host}] (site#{site[:id]})\n#{anon.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") unless anon.save
      site[:anon_id] = anon[:id]

      # =========== CREATE ROOT NODE ============================

      root = site.send(:secure,Project) do
        Project.create( :title => site.name, :rgroup_id => pub[:id], :wgroup_id => sgroup[:id], :dgroup_id => editors[:id], :title => site.name, :v_status => Zena::Status::Pub)
      end

      raise Exception.new("Could not create root node for site [#{host}] (site#{site[:id]})\n#{root.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") if root.new_record?

      Node.connection.execute "UPDATE nodes SET section_id = id, project_id = id WHERE id = '#{root[:id]}'"

      raise Exception.new("Could not publish root node for site [#{host}] (site#{site[:id]})\n#{root.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") unless (root.v_status == Zena::Status::Pub || root.publish)

      site.home_id = root[:id]
      site.root_id = root[:id]
      
      # Make sure safe definitions on Time/Array/String are available on prop_eval validation.
      Zena::Use::ZafuSafeDefinitions
      # Should not be needed since we load PropEval in Node, but it does not work
      # without when doing 'mksite' (works in tests).
      Node.safe_method :now => {:class => Time, :method => 'Time.now'}

      # =========== UPDATE SITE =================================
      # save site definition
      raise Exception.new("Could not save site definition for site [#{host}] (site#{site[:id]})\n#{site.errors.map{|k,v| "[#{k}] #{v}"}.join("\n")}") unless site.save

      # =========== LOAD INITIAL DATA (default skin + roles) =============

      nodes = site.send(:secure, Node) { Node.create_nodes_from_folder(:folder => File.join(Zena::ROOT, 'db', 'init', 'base'), :parent_id => root[:id], :defaults => { :v_status => Zena::Status::Pub, :rgroup_id => pub[:id], :wgroup_id => sgroup[:id], :dgroup_id => editors[:id] } ) }.values
      # == set skin id to 'default' for all elements in the site == #
      skin = nodes.detect {|n| n.kind_of?(Skin) }
      Node.connection.execute "UPDATE nodes SET skin_id = '#{skin.id}' WHERE site_id = '#{site[:id]}'"

      # =========== CREATE CONTACT PAGES ==============
      {
        admin_user => {'first_name' => 'Admin',     'last_name' => 'User'},
        anon       => {'first_name' => 'Anonymous', 'last_name' => 'User'}
      }.each do |user, attrs|
        # forces @node creation
        user.node_attributes = attrs
        user.send(:create_node)
        user.save!
      end

      # == done.
      Site.logger.info "=========================================================="
      Site.logger.info "  NEW SITE CREATED FOR [#{host}] (site#{site[:id]})"
      Site.logger.info "=========================================================="

      site.instance_variable_set(:@being_created, false)
      site
    end
    
    def master_sites
      Site.all(:conditions => ['master_id is NULL'])
    end

    def find_by_host(host)
      host = $1 if host =~ /^(.*)\.$/
      if site = self.find(:first, :conditions => ['host = ?', host]) rescue nil
        setup_master(site)
      else
        nil
      end
    end
    
    def setup_master(site)
      if id = site.master_id
        # The loaded site is an alias, load master site.
        master = self.find(:first, :conditions => ['id = ?', id])
        master.alias = site
        master
      else
        site
      end
    end

    # List of attributes that can be configured in the admin form
    def attributes_for_form(is_alias = false)
      is_alias ? @@alias_attributes_for_form : @@attributes_for_form
    end
  end

  property.string 'usr_prototype_attributes'  
  property.boolean 'expire_in_dev'
  property.boolean 'ssl_on_auth'

  Site.attributes_for_form[:text] << 'usr_prototype_attributes'
  Site.attributes_for_form[:bool] << 'expire_in_dev'
  attr_accessible :usr_prototype_attributes, :expire_in_dev
  
  # Return path for static/cached content served by proxy: RAILS_ROOT/sites/_host_/public
  # If you need to serve from another directory, we do not store the path into the sites table
  # for security reasons. The easiest way around this limitation is to symlink the 'public' directory.
  def public_path
    "/#{host}#{PUBLIC_PATH}"
  end
  
  # This is the place where cached files should be stored in case we do not want
  # to store the cached file inside the public directory.
  def cache_path
    "/#{host}#{CACHE_PATH}"
  end

  # Return path for documents data: RAILS_ROOT/sites/_host_/data
  # You can symlink the 'data' directory if you need to keep the data in some other place.
  def data_path
    "/#{master_host}/data"
  end

  # Return the path for zafu rendered templates: RAILS_ROOT/sites/_host_/zafu
  def zafu_path
    "/#{master_host}/zafu"
  end
  
  # Return the anonymous user, the one used by anonymous visitors to visit the public part
  # of the site.
  def anon
    @anon ||= User.find_by_id_and_site_id(self[:anon_id], self.id)
  end

  # Return an admin user, this user is used to rebuild index/vhash/etc.
  def any_admin
    @any_admin ||= User.find_by_status_and_site_id(User::Status[:admin], self.id)
  end

  # Return the root node or a dummy if the visitor cannot view root
  # node (such as during a 404 or login rendering).
  def root_node
    @root ||= secure(Node) { Node.find(root_id) } || Node.new(:title => host)
  end
  
  # Return the home node.
  def home_node
    @home ||= secure(Node) { Node.find(home_id) } || Node.new(:title => host)
  end

  # Return the public group: the one in which every visitor belongs.
  def public_group
    @public_group ||= secure(Group) { Group.find(self[:public_group_id]) }
  end

  # Return the site group: the one in which every visitor except 'anonymous' belongs (= all logged in users).
  def site_group
    @site_group ||= secure(Group) { Group.find(self[:site_group_id]) }
  end

  # Return the API group: the one in which API visitors must be to use the API.
  def api_group
    @api_group ||= secure(Group) { Group.find_by_id(self[:api_group_id]) }
  end

  # Return true if the given user is an administrator for this site.
  def is_admin?(user)
    admin_user_ids.include?(user[:id])
  end

  # Return the ids of the administrators of the current site.
  def admin_user_ids
    # TODO: PERFORMANCE admin_user_ids could be cached in the 'site' record.
    @admin_user_ids ||= secure!(User) { User.find(:all, :conditions => "status >= #{User::Status[:admin]}") }.map {|r| r[:id]}
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
    [anon_id, visitor.id] # cannot remove self
  end

  # Return an array with the languages for the site.
  def lang_list
    (self[:languages] || "").split(',').map(&:strip)
  end
  
  ###### Alias handling
  def is_alias?
    !self[:master_id].blank?
  end
  
  # This is the host of the master site.
  def master_host
    self[:host]
  end
  
  # Host with aliasing (returns alias host if alias is loaded)
  def host
    @alias && @alias.host || master_host
  end
  
  def ssl_on_auth
    @alias && @alias.prop['ssl_on_auth'] || self.prop['ssl_on_auth']
  end
  
  # Return true if the site is configured to automatically publish redactions
  def auto_publish?
    @alias && @alias[:auto_publish] || self[:auto_publish]
  end
  
  # Return true if the site is configured to force authentication
  def authentication?
    @alias && @alias[:authentication] || self[:authentication]
  end
  
  def home_id
    @home_id ||= @alias && @alias[:home_id] || self[:home_id] || self[:root_id]
  end
  
  def home_zip
    home_node.zip
  end
  
  def home_zip=(zip)
    if id = secure(Node) { Node.translate_pseudo_id(zip) }
      self[:home_id] = id
    else
      @home_zip_error = _('could not be found')
    end
  end

  def skin_zip
    skin ? skin.zip : nil
  end
  
  def skin_zip=(zip)
    if zip.blank?
      self[:skin_id] = nil
    else
      if id = secure(Node) { Node.translate_pseudo_id(zip) }
        self[:skin_id] = id
      else
        @skin_zip_error = _('could not be found')
      end
    end
  end

  def skin
    secure(Skin) { Skin.find_by_id(skin_id) }
  end

  def skin_id
    @alias && @alias[:skin_id] || self[:skin_id]
  end
  
  def create_alias(hostname)
    raise "Hostname '#{hostname}' already exists" if Site.find_by_host(hostname)
    ali = Site.new(self.attributes)
    ali.host = hostname
    ali.master_id = self.id
    ali.root_id   = self.root_id
    ali.home_id   = self.home_id
    ali.prop      = self.prop
    ali.save
    ali
  end
  ######

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
    Zena::Db.execute "UPDATE sites SET formats_updated_at = (SELECT updated_at FROM iformats WHERE site_id = #{self[:id]} ORDER BY iformats.updated_at DESC LIMIT 1) WHERE id = #{self[:id]}"
    if $iformats
      $iformats[self[:id]] = @iformats = nil
    end
  end

  def virtual_classes
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
    Zena::Db.execute "UPDATE sites SET formats_updated_at = (SELECT updated_at FROM iformats WHERE site_id = #{self[:id]} ORDER BY iformats.updated_at DESC LIMIT 1) WHERE id = #{self[:id]}"
    if $iformats
      $iformats[self[:id]] = @iformats = nil
    end
  end

  def clear_cache(should_clear_zafu = true)
    paths = ["#{SITES_ROOT}#{self.cache_path}"]
    aliases = Site.all(:conditions => {:master_id => self.id})
    aliases.each do |site|
      paths << "#{SITES_ROOT}#{site.cache_path}"
    end
    Site.logger.error("\n-----------------\nCLEAR CACHE FOR SITE #{host} (#{aliases.map(&:host).join(', ')})\n-----------------\n")

    paths.each do |path|
      if File.exist?(path)
        # First remove DB entries so that we do not risk race condition where a cached page is created during
        # filesystem operation and before.
        Zena::Db.execute "DELETE FROM caches WHERE site_id = #{self[:id]}"
        Zena::Db.execute "DELETE FROM cached_pages_nodes WHERE cached_pages_nodes.node_id IN (SELECT nodes.id FROM nodes WHERE nodes.site_id = #{self[:id]})"
        Zena::Db.execute "DELETE FROM cached_pages WHERE site_id = #{self[:id]}"
      
        Dir.foreach(path) do |elem|
          next unless elem =~ /^(\w\w\.html|\w\w|login\.html)$/
          FileUtils.rmtree(File.join(path, elem))
        end
      end
    end
    
    clear_zafu if should_clear_zafu

    true
  end
  
  def clear_zafu
    path = "#{SITES_ROOT}#{self.zafu_path}"
    if File.exist?(path)
      FileUtils.rmtree(path)
    end
  end

  # Rebuild vhash indices for the Site. This method uses the Worker thread to rebuild and works on
  # chunks of 50 nodes.
  def rebuild_vhash(nodes = nil, page = nil, page_count = nil)
    if !nodes
      Site.logger.error("\n----------------- REBUILD VHASH FOR SITE #{host} -----------------\n")
      Zena::SiteWorker.perform(self, :rebuild_vhash)
    else
      # do things
      nodes.each do |node|
        node.rebuild_vhash
        Node.connection.execute "UPDATE nodes SET publish_from = #{Node.connection.quote(node.publish_from)}, vhash = #{Node.connection.quote(node.vhash.to_json)} WHERE id = #{node.id}"
      end
    end

    true
  end

  # Rebuild fullpath cache for the Site. This method uses the Worker thread to rebuild and works on
  # chunks of 50 nodes.
  #
  # The visitor used during index rebuild should be an admin user.
  def rebuild_fullpath(nodes = nil, page = nil, page_count = nil)
    if !page
      Zena::SiteWorker.perform(self, :rebuild_fullpath)
    else
      if page == 1
        Site.logger.error("\n----------------- REBUILD FULLPATH FOR SITE #{host} -----------------\n")
      end
      # do things
      Zena::Use::Ancestry.rebuild_all_paths(root_node)
    end

    true
  end
  
  # Rebuild property indices for the Site. This method uses the Worker thread to rebuild and works on
  # chunks of 50 nodes.
  #
  # The visitor used during index rebuild should be an admin user (to index
  # unpublished templates).
  def rebuild_index(nodes = nil, page = nil, page_count = nil)
    if !page
      Zena::SiteWorker.perform(self, :rebuild_index)
    else
      if page == 1
        Site.logger.error("\n----------------- REBUILD INDEX FOR SITE #{host} -----------------\n")
        # Reset reference to cache origin to make sure it is always overwritten
        Zena::Use::ScopeIndex::AVAILABLE_MODELS.each do |klass|
          changes = klass.column_names.select{|n| n =~ %r{(.*)_id}}.reject {|n| %w{node_id site_id}.include?(n)}.map do |c|
            "#{c} = NULL"
          end.join(', ')
          Site.logger.error("#{klass.name}: reset #{changes}\n")
          Zena::Db.execute "UPDATE #{klass.table_name} SET #{changes} WHERE site_id = #{id}"
        end
      end
      # do things
      nodes.each do |node|
        node.rebuild_index!
      end
    end

    true
  end

  # This is only called from the console (not accessible through controllers)
  def remove_from_db
    node_cleanup = nil
    site_id = self.id.to_s
    CLEANUP_SQL.each do |table, clause|
      clause = clause.gsub('?', site_id)
      begin
        Zena::Db.execute("DELETE FROM #{table} WHERE (#{clause})")
      rescue => err
        puts clause
        puts err
      end
    end
  end

  private
    def valid_site
      errors.add(:host, 'invalid') if self[:host].nil? || (self[:host] =~ /^\./) || (self[:host] =~ /[^\w\.\-]/)
      
      if !is_alias?
        errors.add(:languages, 'invalid') unless self[:languages].split(',').inject(true){|i,l| (i && l =~ /^\w\w$/)}
        errors.add(:default_lang, 'invalid') unless self[:languages].split(',').include?(self[:default_lang])
      else
        self[:languages] = nil
        self[:default_lang] = nil
      end
      
      if @home_zip_error
        errors.add('root_zip', @home_zip_error)
        @home_zip_error = nil
      end
      
      if @skin_zip_error
        errors.add('skin_zip', @skin_zip_error)
        @skin_zip_error = nil
      end
    end

end

Bricks.apply_patches
