require 'yaml'
require 'fileutils'

# We need to make sure the RAILS_ENV is set before brick activation or the wrong bricks will
# be loaded.
RAILS_ENV = 'test' if ARGV.join(' ') =~ /zena:(test|build_fixtures)/

require File.join(File.dirname(__FILE__), '..', 'zena', 'info') # to have Zena::ROOT
require File.join(File.dirname(__FILE__), '..', 'bricks') # to have Bricks

Bricks.load_filename('tasks')

def symlink_assets(from, to)
  from = File.expand_path(from)
  to = File.expand_path(to)
  return if from == to
  # FIXME: how do we keep favicon.ico and robots.txt in the root dir of a site ?
  # FIXME: ln should be to 'current' release, not calendar -> /var/zena/releases/20070511195642/public/calendar
  #        we could create a symlink in the sites dir to 'shared' -> /var/zena/current/public
  #        and then symlink with "#{host_path}/public/#{dir}" -> "../shared/public/#{dir}"
  #        OR we could symlink /var/zena/current/...
  ['calendar', 'images', 'javascripts', 'stylesheets'].each do |dir|
    File.unlink("#{to}/public/#{dir}") if File.symlink?("#{to}/public/#{dir}")
    if File.exist?("#{to}/public/#{dir}")
      if File.directory?("#{to}/public/#{dir}")
        # replace each file
        Dir.foreach("#{from}/public/#{dir}") do |f|
          src, trg = "#{from}/public/#{dir}/#{f}", "#{to}/public/#{dir}/#{f}"
          next if f =~ /\A\./
          if File.exist?(trg) || File.symlink?(trg)
            File.unlink(trg)
          end
          FileUtils.symlink_or_copy(src, trg)
        end
      else
        # ignore
        puts "Cannot install assets in #{to}/public/#{dir} (not a directory)"
      end
    else
      FileUtils.symlink_or_copy("#{from}/public/#{dir}", "#{to}/public/#{dir}")
    end
  end
end

def copy_assets(from, to)
  from = File.expand_path(from)
  to = File.expand_path(to)
  return if from == to
  ['config/mongrel_upload_progress.conf', 'lib/upload_progress_server.rb', 'config/deploy.rb', 'config/bricks.yml', 'public/**/*'].each do |base_path|
    if base_path =~ /\*/
      Dir["#{from}/#{base_path}"].each do |path|
        path = path[(from.length + 1)..-1]
        next if File.directory?(path)
        copy_files("#{from}/#{path}", "#{to}/#{path}")
      end
    else
      copy_files("#{from}/#{base_path}", "#{to}/#{base_path}")
    end
  end
end

COPY_FILE_OVERWRITE_ALL = {}

def copy_files(from, to)
  base = File.dirname(to)
  unless File.exist?(base)
    FileUtils.mkpath(base)
  end
  if File.directory?(from)
    Dir.foreach(from) do |f|
      next if f =~ /\A./
      copy_files("#{from}/#{f}", "#{to}/#{f}")
    end
  elsif !ENV['OVERWRITE_ASSETS'] && File.exist?(to)
    if COPY_FILE_OVERWRITE_ALL.has_key?(base)
      if COPY_FILE_OVERWRITE_ALL[base]
        FileUtils.cp(from, base)
      else
        # skip
      end
    elsif File.read(from) != File.read(to)
      # ask
      puts "\n## exists: #{to}\n   (a= overwrite all in same destination, s= overwrite none in same destination)"
      print "   overwrite (ayNs) ? "
      answer = STDIN.gets.chomp.downcase
      case answer
      when 'y'
        FileUtils.cp(from, base)
      when 'a'
        COPY_FILE_OVERWRITE_ALL[base] = true
        puts "overwrite all in #{base}"
        FileUtils.cp(from, base)
      when 's'
        COPY_FILE_OVERWRITE_ALL[base] = false
        puts "overwrite none in #{base}"
      else
        puts "skip #{to}"
      end
    end
  else
    FileUtils.cp(from, base)
  end
end

namespace :zena do
  desc "Copy latest assets from zena gem to application (images, stylesheets, javascripts)."
  task :assets => :zena_config do
    if Zena::ROOT == RAILS_ROOT
      puts "Copy assets should only be used when zena is loaded externally (via gem for example)."
    else
      copy_assets(Zena::ROOT, RAILS_ROOT)
    end
  end

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
          puts "Host already exists in the database. Aborting."
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
            `rake zena:mksymlinks HOST=#{host.inspect}`

            puts "Site [#{host}] created."
          end
        end
      end
    end
  end

  desc "Create symlinks for a site"
  task :mksymlinks => :zena_config do
    unless host = ENV['HOST']
      puts "Please set HOST to the hostname for which you want to update the symlinks. Aborting."
    else
      host_path = "#{SITES_ROOT}/#{host}"

      ['public', 'data', 'log'].each do |dir|
        next if File.exist?("#{host_path}/#{dir}")
        FileUtils.mkpath("#{host_path}/#{dir}")
      end
      if RAILS_ROOT =~ /releases\/\d+/
        root = (Pathname(RAILS_ROOT) + '../../current').to_s
      else
        root = RAILS_ROOT
      end
      symlink_assets(root, host_path)
    end
  end

  desc "Rename a site"
  task :rename_site => :environment do
    # 0. set host name
    unless host = ENV['HOST']
      puts "Please set HOST to the hostname for the new site name. Aborting."
    else
      unless old_host = ENV['OLD_HOST']
        puts "Please set OLD_HOST to the hostname of the old site name. Aborting."
      else
        host_path = "#{SITES_ROOT}/#{old_host}"
        if !site = Site.find_by_host(old_host)
          puts "Old host does not exist in the database. Aborting."
        elsif Site.find_by_host(host)
          puts "New host already exist in the database. Aborting."
        elsif !File.exist?(host_path)
          puts "Path for host files does not exist (#{host_path}). Aborting."
        else
          site.host = host
          if !site.save
            puts "Could not change site name: #{site.errors.inspect}"
          else
            # move files
            FileUtils.mv(host_path, "#{SITES_ROOT}/#{host}")
            puts "Site '#{old_host}' renamed to '#{host}'."
          end
        end
      end
    end
  end

  desc "Load zena settings (sub-task)"
  task :zena_config do
    require File.join(File.dirname(__FILE__),'..','..','lib','zena')
  end

  desc "Remove all zafu compiled templates"
  task :clear_zafu => :zena_config do
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

  desc "Load environment without running brick init code."
  task :environment_without_bricks do
    Bricks.no_init = true
    Rake::Task["environment"].invoke
  end

  desc "Migrate the database through scripts in db/migrate. Target specific brick and version with BRICK=x and VERSION=x"
  task :migrate => :environment_without_bricks do
    if ENV['VERSION'] || ENV['BRICK']
      ENV['BRICK']    ||= 'zena'
      # migrate specific bricks only
      mig_path = Bricks.migrations_for(ENV['BRICK'])
      if File.exist?(mig_path) && File.directory?(mig_path)
        Zena::Migrator.migrate(mig_path, ENV["BRICK"], ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
      else
        puts "Could not find migrations for brick '#{ENV['BRICK']}' ('#{mig_path}' not found)."
      end
    else
      # migrate all to latest
      # Always start with zena migrations
      paths  = {'zena' => Bricks.migrations_for('zena')}
      bricks = %w{zena}
      Bricks.foreach_brick do |brick_name|
        migration_path = Bricks.migrations_for(brick_name)
        next unless File.exist?(migration_path) && File.directory?(migration_path)
        paths[brick_name] = migration_path
        bricks << brick_name
      end

      # Always end with app migrations
      bricks += %w{_app}
      paths['_app'] = "#{RAILS_ROOT}/db/migrate"

      bricks.each do |brick_name, path|
        Zena::Migrator.migrate(paths[brick_name], brick_name == '_app' ? nil : brick_name, nil)
      end
      #ActiveRecord::Migrator.migrate("db/migrate/", nil)
    end
    Rake::Task["db:schema:dump"].invoke if ActiveRecord::Base.schema_format == :ruby
  end

  desc 'Reset development environment (drop database, migrate, rebuild and load fixtures, clone to test)'
  task :reset => :environment do
    if RAILS_ENV == 'production'
      puts "You cannot reset database in production !"
    else
      %w{db:drop db:create zena:migrate zena:build_fixtures db:test:clone}.each do |task|
        puts "******************************* #{task}"
        Rake::Task[task].invoke
      end
    end
  end

  desc 'Rebuild foxy fixtures for all sites'
  task :build_fixtures => :environment do
    if RAILS_ENV != 'test'
      puts "## You can only build fixtures by using the test environment to avoid loosing data (used = #{RAILS_ENV})"
    else
      Dir["#{RAILS_ROOT}/test/fixtures/*.yml"].each do |f|
        FileUtils.rm f
      end

      tables = Node.connection.tables
      ordered_tables = %w{roles versions nodes attachments zips relations links}

      tables -= ordered_tables
      tables += ordered_tables
      roles, versions, nodes = nil, nil, nil
      tables.each do |table|
        case table
        when 'roles'
          roles = Zena::FoxyParser.new(table)
          roles.run
        when 'versions'
          versions = Zena::FoxyParser.new(table)
          versions.run
        when 'nodes'
          nodes = Zena::FoxyParser.new(table, :versions => versions, :roles => roles)
          nodes.run
        when 'zips'
          Zena::FoxyParser.new(table, :nodes => nodes).run
        when 'relations'
          Zena::FoxyParser.new(table, :roles => roles).run
        when 'links'
          Zena::FoxyParser.new(table, :nodes => nodes).run
        else
          Zena::FoxyParser.new(table).run
        end
      end

      %w{db:fixtures:load zena:rebuild_index}.each do |task|
        puts "******************************* #{task}"
        Rake::Task[task].invoke
      end

      index_tables = Node.connection.tables.select {|t| t =~ /^idx_/ }
      Zena::FoxyParser.dump_fixtures(index_tables)
    end
  end

  desc 'Rebuild index for all sites or site defined by HOST param.'
  task :rebuild_index => :environment do
    include Zena::Acts::Secure
    if ENV['HOST']
      sites = [Site.find_by_host(ENV['HOST'])]
    else
      sites = Site.all
    end
    sites.each do |site|
      if ENV['WORKER'] == 'false'
        # We avoid SiteWorker by passing nodes.
        Thread.current[:visitor] = site.any_admin
        nodes = Node.find(:all,
          :conditions => ['site_id = ?', site.id]
        )
        site.rebuild_index(secure_result(nodes))
      else
        # We try to use the site worker.
        Thread.current[:visitor] = site.any_admin
        site.rebuild_index
      end
    end
  end

  desc 'Rebuild fullpath for all sites or site defined by HOST param.'
  task :rebuild_fullpath => :environment do
    include Zena::Acts::Secure
    if ENV['HOST']
      sites = [Site.find_by_host(ENV['HOST'])]
    else
      sites = Site.all
    end
    sites.each do |site|
      # Does not use SiteWorker.
      site.rebuild_fullpath
    end
  end

  desc 'Rebuild vhash for all sites or site defined by HOST param.'
  task :rebuild_vhash => :environment do
    include Zena::Acts::Secure
    if ENV['HOST']
      sites = [Site.find_by_host(ENV['HOST'])]
    else
      sites = Site.all
    end
    sites.each do |site|
      # We avoid SiteWorker by passing nodes.
      Thread.current[:visitor] = site.any_admin
      nodes = Node.find(:all,
        :conditions => ['site_id = ?', site.id]
      )
      site.rebuild_vhash(secure_result(nodes))
    end
  end

  Rake::RDocTask.new do |rdoc|
       files = ['README', 'doc/README_FOR_APP', 'CREDITS', 'MIT-LICENSE', 'app/**/*.rb',
                'lib/**/*.rb']
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

  tests = ['test/unit/**/*_test.rb', 'test/functional/*_test.rb', 'test/integration/*_test.rb'].map {|p| "#{Zena::ROOT}/#{p}"}

  tests += Bricks.test_files

  Rake::TestTask.new(:test => ["zena:test:prepare", "zena:build_fixtures"]) do |t|
    t.libs << "test"
    t.pattern = tests
    t.verbose = true
  end
  Rake::Task['zena:test'].comment = "Run the tests in test/helpers and test/unit"

  desc 'Analyse code coverage by tests (needs rcov)'
  task :coverage do
    cmd = "rcov -I 'lib:test' --rails --exclude 'var/*,gems/*,/Library/*'"
    test_files = FileList[*tests].map {|f| f.inspect}.join(' ')
    cmd = "#{cmd} #{test_files}"
    exec(cmd)
  end

  namespace :fix do
    desc "Update all stored zafu to reflect change from 'news from project' syntax to 'news in project'. BACKUP BEFORE. DO NOT RUN."
    task :zafu_pseudo_sql => :environment do
      unless ENV['CODE'] == 'yes do it'
        puts "set CODE='yes do it' if you really want to run this (DO NOT RUN if unsure)."
      else
        {
          # 1. replace all finders like 'xyz from project' by 'xyz in project'
          ' from project' => ' in project',
          ' from section' => ' in section',
          ' from site' => ' in site',
          ' from  project' => ' in project',
          ' from  section' => ' in section',
          ' from  site' => ' in site',
          ' from   project' => ' in project',
          ' from   section' => ' in section',
          ' from   site' => ' in site',
          # 2. replace all finders like <:xyz from='project'... by <:xyz in='project'
          # 2.1 single quote
          " from='project'" => " in='project'",
          " from='section'" => " in='section'",
          " from='site'" => " in='site'",
          " from ='project'" => " in='project'",
          " from ='section'" => " in='section'",
          " from ='site'" => " in='site'",
          " from = 'project'" => " in='project'",
          " from = 'section'" => " in='section'",
          " from = 'site'" => " in='site'",
          " from= 'project'" => " in='project'",
          " from= 'section'" => " in='section'",
          " from= 'site'" => " in='site'",
          # 2.1 double quote
          ' from="project"' => ' in="project"',
          ' from="section"' => ' in="section"',
          ' from="site"' => ' in="site"',
          ' from ="project"' => ' in="project"',
          ' from ="section"' => ' in="section"',
          ' from ="site"' => ' in="site"',
          ' from = "project"' => ' in="project"',
          ' from = "section"' => ' in="section"',
          ' from = "site"' => ' in="site"',
          ' from= "project"' => ' in="project"',
          ' from= "section"' => ' in="section"',
          ' from= "site"' => ' in="site"',
          # kpath
          'NPD' => 'ND',
        }.each do |k,v|
          Version.connection.execute "UPDATE versions, nodes SET versions.text = REPLACE(text, #{Version.connection.quote(k)}, #{Version.connection.quote(v)}) WHERE versions.node_id = nodes.id AND nodes.kpath = 'NDTT'" # Template
        end
      end
    end
  end

  namespace :sessions do
    desc "Count database sessions"
    task :count => :environment do
      count = ActiveRecord::SessionStore::Session.count
      puts "Sessions stored: #{count}"
    end

    desc "Clear database-stored sessions older than two weeks"
    task :prune => :environment do
      ActiveRecord::SessionStore::Session.delete_all [ "updated_at < ?", 2.weeks.ago
      ]
    end
  end

  desc "Create the database, migrate, create 'localhost' site and start application (in production environment by default)"
  task :init do
    # FIXME: how to run sub-task
    ENV['RAILS_ENV'] = RAILS_ENV || 'production'
    ENV['HOST']      ||= 'localhost'
    ENV['LANG']        = ENV['LANG'].to_s
    ENV['LANG']        = 'en' if ENV['LANG'].empty?
    ENV['PASSWORD']  ||= 'admin'

    Rake::Task["db:create"].invoke
    Rake::Task["zena:migrate"].invoke

    # We cannot use 'invoke' here because the User class needs to be reloaded
    env = %w{RAILS_ENV HOST LANG PASSWORD}.map{|e| "#{e}=#{ENV[e]}"}.join(' ')
    cmd = "rake zena:mksite #{env}"
    puts cmd
    system(cmd)

    if RUBY_PLATFORM =~ /mswin32/
      puts "\n\nOnce the server has started, you can open your web browser at:\n\n\n           ====> http://localhost:3000 <====\n\n\n"
      cmd = "ruby script/server -e #{ENV['RAILS_ENV']} -p 3000"
      puts cmd
      system cmd
    else
      cmd = "open #{File.join(Zena::ROOT, 'lib/zena/deploy/start.html').inspect}"
      puts cmd
      system(cmd)

      cmd = "ruby script/server -e #{ENV['RAILS_ENV']} -p 3000"
      puts cmd
      exec cmd
    end
  end

end
