require 'yaml'
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
            ['calendar', 'images', 'javascripts', 'stylesheets'].each do |dir|
              FileUtils.ln_s("#{RAILS_ROOT}/public/#{dir}", "#{host_path}/public/#{dir}")
            end
            
            puts "Site [#{host}] created."
          end
        end
      end
    end
  end
  
  task :init => :environment do
    Dir.foreach("#{RAILS_ROOT}/db/init") do |file|
      next unless file =~ /.+\.yml$/
      Zena::Loader::load_file(File.join("#{RAILS_ROOT}/db/init", file))
    end
  end
  
  desc "Migrate the database through scripts in db/migrate. Target specific brick and version with BRICK=x and VERSION=x"
  task :migrate => :environment do
    if ENV['BRICK']
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
    elsif ENV['VERSION']
      # migrate normal app files with version
      ActiveRecord::Migrator.migrate("db/migrate/", ENV["VERSION"].to_i)
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
  
  Rake::TestTask.new(:test => "db:test:prepare") do |t|
    t.libs << "test"
    t.pattern = ['test/helpers/**/*_test.rb','test/unit/**/*_test.rb', 'lib/parser/test/*_test.rb']
    t.verbose = true
  end
  Rake::Task['zena:test'].comment = "Run the tests in test/helpers and test/unit"
end

namespace :test do
  
  Rake::TestTask.new(:helpers => "db:test:prepare") do |t|
    t.libs << "test"
    t.pattern = 'test/helpers/**/*_test.rb'
    t.verbose = true
  end
  Rake::Task['test:helpers'].comment = "Run the tests in test/helpers"
end

