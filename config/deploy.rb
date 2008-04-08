=begin

Deployment 'recipe' for capistrano. Creates everything for your zena app.

Assumed: 
  - mysql root user has the same password as ssh
  - you are using apache 2.2+ (using balance_proxy)
  - server is running debian etch
  - you have installed subversion on the server (aptitude install subversion)
  - you have installed mysql on the server (aptitude install mysql...)
  - you have installed the required dependencies (see main README file)
  
========== USAGE ==========

1. Copy the file 'deploy_config_example.rb' to 'deploy_config.rb' and edit the entries in this new file.
2. Run => cap initial_setup
3. Run => cap mksite -s host='example.com' -s pass='secret' -s lang='en'

If anything goes wrong, ask the mailing list (lists.zenadmin.org) or read the content of this file to understand what went wrong...


=end
require 'erb'
load File.join(File.dirname(__FILE__), 'deploy_config')

#================= ADVANCED SETTINGS =============#

set :deploy_to,    "/var/zena"
role :web,         "root@#{server_ip}"
role :app,         "root@#{server_ip}"
role :db,          "root@#{server_ip}", :primary => true
set :apache2_deflate,       true
set :apache2_debug_deflate, false
set :apache2_debug_rewrite, false
# cgi-bin not working...? FIXME: set :apache2_static,        ['cgi-bin', 'awstats-icon']
set :apache2_static,        []

#================= END ADVANCED SETTINGS ==========#


# helper
set :in_current, "cd #{deploy_to}/current &&"
class RenderClass
  def initialize(path)
    @text = File.read(path)
  end
  
  def render(hash)
    @values = hash
    ERB.new(@text).result(binding)
  end
  
  def method_missing(sym)
    return @values[sym] if @values.has_key?(sym)
    super
  end
end

def render(file, hash)
  RenderClass.new(file).render(hash)
end

#========================== SOURCE CODE   =========================#


desc "set permissions to www-data"
task :set_permissions, :roles => :app do
  run "chown -R www-data:www-data #{deploy_to}"
  run "chown -R www-data:www-data /var/www/zena"
end

"Update the currently released version of the software directly via an SCM update operation" 
task :update_current do 
  source.sync(revision, self[:release_path]) 
end

desc "clear all zafu compiled templates"
task :clear_zafu, :roles => :app do
  run "#{in_current} rake zena:clear_zafu"
end

desc "clear all cache compiled templates"
task :clear_cache, :roles => :app do
  run "#{in_current} rake zena:clear_cache RAILS_ENV=production"
end

desc "after code update"
task :after_update, :roles => :app do
  app_update_symlinks
  db_update_config
  clear_zafu
  clear_cache
  migrate
end

desc "update symlink to 'sites' directory"
task :app_update_symlinks, :roles => :app do
  run "test ! -e #{deploy_to}/current/sites || rm #{deploy_to}/current/sites"
  run "ln -sf /var/www/zena #{deploy_to}/current/sites"
  set_permissions
end

desc "migrate database (zena version)"
task :migrate, :roles => :db do
  run "#{in_current} rake zena:migrate RAILS_ENV=production"
end

desc "initial app setup"
task :app_setup, :roles => :app do
  run "test -e #{deploy_to}  || mkdir #{deploy_to}"
  run "test -e /var/www/zena || mkdir /var/www/zena"
  deploy::setup
end

#========================== MANAGE HOST   =========================#
desc "create a new site"
task :mksite, :roles => :app do
  run "#{in_current} rake zena:mksite HOST='#{self[:host]}' PASSWORD='#{self[:pass]}' RAILS_ENV='production' LANG='#{self[:lang] || 'en'}'"
  create_vhost
  set_permissions
end

desc "update code in the current version"
task :up, :roles => :app do
  run "cd #{deploy_to}/current && svn up"
  db_update_config
  clear_zafu
  clear_cache
  migrate
  restart
end

#========================== MONGREL ===============================#
desc "configure mongrel"
task :mongrel_setup, :roles => :app do
  run "#{in_current} mongrel_rails cluster::configure -e production -p #{mongrel_port} -N #{mongrel_count} -c #{deploy_to}/current -P log/mongrel.pid -l log/mongrel.log -a 127.0.0.1 --user www-data --group www-data"
  run "#{in_current} echo 'config_script: config/mongrel_upload_progress.conf' >> config/mongrel_cluster.yml"
end

desc "Stop the drb upload_progress server"
task :stop_upload_progress , :roles => :app do
  run "#{in_current} ruby lib/upload_progress_server.rb stop"
end

desc "Start the drb upload_progress server"
task :start_upload_progress , :roles => :app do
  run "#{in_current} lib/upload_progress_server.rb start"
end

desc "Restart the upload_progress server"
task :restart_upload_progress, :roles => :app do
  stop_upload_progress
  start_upload_progress
end

desc "Start mongrel"
task :start, :roles => :app do
  restart_upload_progress
  run "#{in_current} mongrel_rails cluster::start"
end

desc "Stop mongrel"
task :stop, :roles => :app do
  stop_upload_progress
  run "#{in_current} mongrel_rails cluster::stop"
end

desc "Restart mongrel"
task :restart, :roles => :app do
  stop
  restart_upload_progress
  start
end

#========================== APACHE2 ===============================#
desc "Update vhost configuration file"
task :create_vhost, :roles => :web do
  unless self[:host]
    puts "HOST not set (use -s host=...)"
  else
    vhost = render("config/vhost.rhtml", 
                  :host        => self[:host],
                  :static      => apache2_static,
                  :deflate       => apache2_deflate,
                  :debug_deflate => apache2_debug_deflate,
                  :debug_rewrite => apache2_debug_rewrite,
                  :balancer    => db_name
                  )
    put(vhost, "/etc/apache2/sites-available/#{self[:host]}")
    run "test -e /etc/apache2/sites-enabled/#{self[:host]} || a2ensite #{self[:host]}"
    run "/etc/init.d/apache2 reload"
  end
end

desc "Rename a webhost"
task :rename_host, :roles => :web do
  unless self[:host] && self[:old_host]
    puts "host or old_host not set (use -s host=... -s old_host=...)"
  else
    run "#{in_current} rake zena:rename_host OLD_HOST='#{self[:old_host]}' HOST='#{self[:host]}' RAILS_ENV='production'"
    create_vhost
    set_permissions
    old_vhost_path = "/etc/apache2/sites-available/#{self[:old_host]}"
    run "test -ne #{old_vhost_path} || rm #{old_vhost_path}"
    run "a2dissite #{self[:old_host]}"
    run "/etc/init.d/apache2 reload"
  end
end

desc "Apache2 initial setup"
task :apache2_setup, :roles => :web do
  ports = (mongrel_port.to_i...(mongrel_port.to_i + mongrel_count.to_i)).to_a
  httpd_conf = render("config/httpd.rhtml", :balancer => db_name, :ports => ports)
  put(httpd_conf, "/etc/apache2/conf.d/#{db_name}")
  
  run "test -e /etc/apache2/sites-enabled/000-default && a2dissite default || echo 'default already disabled'"
  run "test -e /etc/apache2/mods-enabled/rewrite.load || a2enmod rewrite"
  run "test -e /etc/apache2/mods-enabled/proxy_balancer.load || a2enmod proxy_balancer"
  run "test -e /etc/apache2/mods-enabled/proxy.load || a2enmod proxy"
  run "test -e /etc/apache2/mods-enabled/proxy_http.load || a2enmod proxy_http"
  run "/etc/init.d/apache2 force-reload"
end

#========================== MYSQL   ===============================#

desc "set database.yml file according to settings"
task :db_update_config, :roles => :app do
  db_app_config = render("config/database.rhtml", 
                :db_name     => db_name,
                :db_user     => db_user,
                :db_password => db_password
                )
  put(db_app_config, "#{deploy_to}/current/config/database.yml")
end

desc "create database"
task :db_create, :roles => :db do
  on_rollback do
    run "mysql -u root -p -e \"DROP DATABASE #{db_name};\"" do |channel, stream, data|
      if data =~ /^Enter password:\s*/m
        logger.info "#{channel[:host]} asked for password"
        channel.send_data "#{password}\n"
      end
      puts data
    end
  end
  
  run "mysql -u root -p -e \"CREATE DATABASE #{db_name} DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci; GRANT ALL ON #{db_name}.* TO '#{db_user}'@'localhost' IDENTIFIED BY '#{db_password}';\"" do |channel, stream, data|
    if data =~ /^Enter password:\s*/m
      logger.info "#{channel[:host]} asked for password"
      channel.send_data "#{password}\n"
    end
    puts data
  end
end

desc "initial database setup"
task :db_setup, :roles => :db do
  transaction do
    db_create
  end
end


desc "Full initial setup"
task :initial_setup do
  transaction do
    app_setup
    
    db_setup
    
    deploy::update_code
    
    mongrel_setup

    apache2_setup
  
    set_permissions

    start
  end
end

desc "Database dump"
task :db_dump, :roles => :db do
  run "mysqldump #{db_name} -u root -p > #{deploy_to}/current/#{db_name}.sql" do |channel, stream, data|
    if data =~ /^Enter password:\s*/m
      logger.info "#{channel[:host]} asked for password"
      channel.send_data "#{password}\n"
    end
    puts data
  end
  run "#{in_current} tar czf #{db_name}.sql.tgz #{db_name}.sql"
  run "#{in_current} rm #{db_name}.sql"
end

desc "Get backup file back"
task :get_backup, :roles => :app do
  get "#{deploy_to}/current/#{db_name}_data.tgz", "./#{db_name}_#{Time.now.strftime '%Y-%m-%d-%H'}.tgz"
end

# FIXME: backup not loading data for every site...
desc "Backup all data and bring it backup here"
task :backup, :roles => :app do
  db_dump
  # key track of the current svn revision for app
  
  run "#{in_current} svn info > #{deploy_to}/current/zena_version.txt"
  run "#{in_current} rake zena:full_backup RAILS_ENV='production'"
  run "#{in_current} tar czf #{db_name}_data.tgz #{db_name}.sql.tgz sites_data.tgz zena_version.txt"
  get_backup
end
