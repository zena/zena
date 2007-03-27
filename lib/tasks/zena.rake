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
        def create(opts)
          h = {}
          opts.each_pair do |k,v|
            if :type == k
              h[:_type_] = v
            else
              h[k] = v
            end
          end
          super(h)
        end
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
          unless YamlLoader.create(record)
            puts "could not create #{klass} #{record.inspect}"
          end
        end
      end
    end
  end
end


namespace :zena do
  desc "Create a new site"
  task :mksite => :environment do
    # 0. set host name
    unless host = ENV['HOST']
      puts "Please set HOST to the hostname for the new site. Aborting."
    else
      unless pass = ENV['PASSWORD']
        puts "Please set PASSWORD to the admin password for the new site. Aborting."
      else  
        host_path = "#{SITES_ROOT}/#{host}"
        if Site.find_by_host(host)
          puts "Host allready exists in the database. Aborting."
        elsif File.exist?(host_path)
          puts "Path for host files exists (#{host_path}). Aborting."
        else
          site = Site.create_for_host(host, pass)
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
            
            Dir.foreach("#{RAILS_ROOT}/db/init") do |file|
              next unless file =~ /.+\.yml$/
              Zena::Loader::load_file(File.join("#{RAILS_ROOT}/db/init", file))
            end
            
            puts "Site [#{host}] created."
          end
        end
      end
    end
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
end

