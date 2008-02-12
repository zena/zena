require 'yaml'
require 'fileutils'

module Zena
  # mass yaml loader for ActiveRecord (a single file can contain different classes)
  module Loader
    class YamlLoader < ActiveRecord::Base
      class << self
        def set_table(tbl)
          set_table_name tbl
          reset_column_information
        end
        
        def create_or_update(opts)
          h = {}
          opts.each_pair do |k,v|
            if :type == k
              h['_type_'] = v
            else
              h[k.to_s] = v
            end
          end
          
          if h['id'] && obj = find_by_id(h['id'])
            res = []
            h.each do |k,v|
              res << "`#{k}` = #{v ? v.inspect : 'NULL'}"
            end
            connection.execute "UPDATE #{table_name}  SET #{res.join(', ')} WHERE id = #{h['id']}"
          else
            keys   = []
            values = []
            h.each do |k,v|
              keys   << "`#{k}`"
              values << (v ? v.inspect : 'NULL')
            end
            connection.execute "INSERT INTO #{table_name} (#{keys.join(', ')}) VALUES (#{values.join(', ')})"
          end
        end
      end
      
      def site_id=(i)
        self[:site_id] = i
      end
      
      def _type_=(t)
        self.type = t
      end
    end

    def self.load_file(filepath)
      raise Exception.new("Invalid filepath for loader (#{filepath})") unless ((filepath =~ /.+\.yml$/) && File.exist?(filepath))
      base_objects = {}
      YAML::load_documents( File.open( filepath ) ) do |doc|
        doc.each do |elem|
          list = elem[1].map do |l|
            hash = {}
            l.each_pair do |k, v|
              hash[k.to_sym] = v
            end
            hash
          end
          tbl = elem[0].to_sym
          if base_objects[tbl]
            base_objects[tbl] += list
          else
            base_objects[tbl] = list
          end
        end
      end

      base_objects.each_pair do |tbl, list|
        YamlLoader.set_table(tbl.to_s)
        list.each do |record|
          YamlLoader.create_or_update(record)
        end
      end
    end
  end
end


namespace :zena do
  desc "Create a new site, parameters are PASSWORD, HOST, LANG"
  task :mksite => :environment do
    # 0. set host name
    unless host = ENV['HOST']
      puts "Please set HOST to the hostname for the new site. Aborting."
    else
      unless pass = ENV['PASSWORD']
        puts "Please set PASSWORD to the admin password for the new site. Aborting."
      else  
        ENV['LANG'] ||= 'en'
        host_path = "#{SITES_ROOT}/#{host}"
        if Site.find_by_host(host)
          puts "Host allready exists in the database. Aborting."
        elsif File.exist?(host_path)
          puts "Path for host files exists (#{host_path}). Aborting."
        else
          site = Site.create_for_host(host, pass, :default_lang => ENV['LANG'])
          if site.new_record?
            puts "Could not create site ! Errors:"
            site.errors.each do |k,v|
              puts "[#{k}] #{v}"
            end
            puts "Aborting."
          else
            # 1. create directories and symlinks
            ['public', 'data', 'log'].each do |dir|
              FileUtils.mkpath("#{host_path}/#{dir}")
            end
      
            # FIXME: how do we keep favicon.ico and robots.txt in the root dir of a site ?
            # FIXME: ln should be to 'current' release, not calendar -> /var/zena/releases/20070511195642/public/calendar
            #        we could create a symlink in the sites dir to 'shared' -> /var/zena/current/public
            #        and then symlink with "#{host_path}/public/#{dir}" -> "../shared/public/#{dir}"
            #        OR we could symlink /var/zena/current/...
            ['calendar', 'images', 'javascripts', 'stylesheets', 'icons'].each do |dir|
              # FIXME: 'RAILS_ROOT' should be '/var/zena/current' and not '/var/zena/releases/20070632030330' !!!
              FileUtils.ln_s("#{RAILS_ROOT}/public/#{dir}", "#{host_path}/public/#{dir}")
            end
            
            puts "Site [#{host}] created."
          end
        end
      end
    end
  end
  
  desc "Remove all zafu compiled templates"
  task :clear_zafu do
    if File.exist?(SITES_ROOT)
      Dir.foreach(SITES_ROOT) do |site|
        next if site =~ /^\./
        FileUtils.rmtree(File.join(SITES_ROOT, site, 'zafu'))
      end
    end
  end
  
  desc "Remove all cached data" # FIXME: cachedPages db should be cleared to
  task :clear_cache => :environment do
    if File.exist?(SITES_ROOT)
      Dir.foreach(SITES_ROOT) do |site|
        next if site =~ /^\./ || !File.exist?(File.join(SITES_ROOT,site,'public'))
        Dir.foreach(File.join(SITES_ROOT,site,'public')) do |elem|
          next unless elem =~ /^(\w\w\.html|\w\w)$/
          FileUtils.rmtree(File.join(SITES_ROOT, site, 'public', elem))
        end
      end
      ['caches', 'cached_pages', 'cached_pages_nodes'].each do |tbl|
        Site.connection.execute "DELETE FROM #{tbl}"
      end
    end
  end
  
  desc "Create a backup of all data for a site"
  task :backup_site do
    unless host = ENV['HOST']
      puts "Please set HOST to the hostname for the site to backup. Aborting."
    else
      path = File.join(SITES_ROOT,ENV['HOST'])
      unless File.exist?(path)
        puts "Site does not exist in '#{SITES_ROOT}'"
      else
        folders = ['data'].map {|f| File.join(SITES_ROOT,f) }
        cmd = "tar czf #{path}_data.tgz #{folders.join(' ')}"
        puts cmd
        puts `#{cmd}`
      end
    end
  end
  
  task :full_backup => :environment do
    data_folders = Site.find(:all).map { |s| File.join(SITES_ROOT, s.data_path) }.reject { |p| !File.exist?(p) }
    cmd = "tar czf #{RAILS_ROOT}/sites_data.tgz #{data_folders.join(' ')}"
    puts cmd
    puts `#{cmd}`
  end
  
  desc "Migrate the database through scripts in db/migrate. Target specific brick and version with BRICK=x and VERSION=x"
  task :migrate => :environment do
    if ENV['VERSION'] || ENV['BRICK']
      ENV['BRICK']    ||= 'zena'
      # migrate specific bricks only
      mig_path = nil
      Dir.foreach('db/migrate') do |file|
        next if file =~ /^\./
        next unless File.stat("db/migrate/#{file}").directory?
        if file =~ /^[0-9-_]*#{ENV["BRICK"]}/
          mig_path = "db/migrate/#{file}"
          break
        end
      end
      if mig_path
        ActiveRecord::BricksMigrator.migrate(mig_path, ENV["BRICK"], ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
      else
        puts "Brick migrations must exist in db/migrate/BRICK"
      end
    else
      # migrate all to latest
      directories = []
      Dir.foreach('db/migrate') do |file|
        next if file =~ /^\./
        next unless File.stat("db/migrate/#{file}").directory?
        directories << file
      end
      directories.sort.each do |file|
        brick_name = file.sub(/^[0-9-_]*/,'')
        ActiveRecord::BricksMigrator.migrate("db/migrate/#{file}", brick_name, nil)
      end
      ActiveRecord::Migrator.migrate("db/migrate/", nil)
    end
    Rake::Task["db:schema:dump"].invoke if ActiveRecord::Base.schema_format == :ruby
  end
  
  Rake::RDocTask.new do |rdoc|
       files = ['README', 'doc/README_FOR_APP', 'CREDITS', 'TODO', 'LICENSE', 'app/**/*.rb', 
                'lib/**/*.rdoc']
       rdoc.rdoc_files.add(files)
       rdoc.main = "doc/README_FOR_APP" # page to start on
       rdoc.title = "Zena Documentation"
       rdoc.template = "./doc/template/allison.rb"
       rdoc.rdoc_dir = 'doc/app' # rdoc output folder
       rdoc.options << '--line-numbers' << '--inline-source'
  end
  Rake::Task['zena:rdoc'].comment = "Create the rdoc documentation"
  
  namespace :test do
    desc 'Cleanup before testing'
    task :prepare => "db:test:prepare" do
      [File.join(SITES_ROOT, 'test.host', 'data'), File.join(SITES_ROOT, 'test.host', 'zafu')].each do |path|
        FileUtils::rmtree(path) if File.exist?(path)
      end
    end
  end
  
  Rake::TestTask.new(:test => "zena:test:prepare") do |t|
    t.libs << "test"
    # do not change the order in which these elements are loaded
    t.pattern = ['test/helpers/**/*_test.rb','test/unit/**/*_test.rb', 'lib/parser/test/*_test.rb', 'test/integration/*_test.rb']
    t.verbose = true
  end
  Rake::Task['zena:test'].comment = "Run the tests in test/helpers and test/unit"
end


# ============ GetText ================
require 'gettext/utils'
desc "Create mo-files for L10n" 
task :makemo do
  GetText.create_mofiles(true, "po", "locale")
end

desc "Update pot/po files to match new version." 
task :updatepo do 
  GetText::ActiveRecordParser.init(:use_classname => false, :db_mode => "development")
  GetText.update_pofiles('zena', Dir.glob("{app,lib}/**/*.{rb,rhtml,erb,rjs}"), Zena::VERSION::STRING)
end


module ActiveRecord
  class BricksMigrator < Migrator
    class << self
      def migrate(migrations_path, brick_name, target_version = nil)
        self.init_bricks_migration_table
        case
        when target_version.nil?, current_version(brick_name) < target_version
          up(migrations_path, brick_name, target_version)
        when current_version(brick_name) > target_version
          down(migrations_path, brick_name, target_version)
        when current_version(brick_name) == target_version
          return # You're on the right version
        end
      end

      def up(migrations_path, brick_name, target_version = nil)
        self.new(:up, migrations_path, brick_name, target_version).migrate
      end

      def down(migrations_path, brick_name, target_version = nil)
        self.new(:down, migrations_path, brick_name, target_version).migrate
      end

      def bricks_info_table_name
        Base.table_name_prefix + "bricks_info" + Base.table_name_suffix
      end

      def current_version(brick_name)
        begin
          ActiveRecord::Base.connection.select_one("SELECT version FROM #{bricks_info_table_name} WHERE brick = '#{brick_name}'")["version"].to_i
        rescue
          ActiveRecord::Base.connection.execute "INSERT INTO #{bricks_info_table_name} (brick, version) VALUES('#{brick_name}',0)"
          0
        end
      end

      def init_bricks_migration_table
        begin
          ActiveRecord::Base.connection.execute "CREATE TABLE #{bricks_info_table_name} (version #{Base.connection.type_to_sql(:integer)}, brick #{Base.connection.type_to_sql(:string)})"
        rescue ActiveRecord::StatementInvalid
          # Schema has been intialized
        end
      end
    end

    def initialize(direction, migrations_path, brick_name, target_version = nil)
      raise StandardError.new("This database does not yet support migrations") unless Base.connection.supports_migrations?
      @direction, @migrations_path, @brick_name, @target_version = direction, migrations_path, brick_name, target_version
      self.class.init_bricks_migration_table
    end

    def current_version
      self.class.current_version(@brick_name)
    end

    private

    def set_schema_version(version)
      Base.connection.update("UPDATE #{self.class.bricks_info_table_name} SET version = #{down? ? version.to_i - 1 : version.to_i} WHERE brick = '#{@brick_name}'")
    end
  end
end