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
3. Run => cap mksite -s host='example.com' -s password='secret'

If anything goes wrong, ask the mailing list (lists.zenadmin.org) or read the content of this file to understand what whent wrong...


=end

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
set :in_deploy, "cd #{deploy_to}/current &&"

#========================== SOURCE CODE   =========================#
desc "set permissions to www-data"
task :set_permissions, :roles => :app do
  run "chown -R www-data:www-data #{deploy_to}"
  run "chown -R www-data:www-data /var/www/zena"
end

desc "push local changes by doing an svk checkin and updating code"
task :push, :roles => :app do
  system "svk st && svk ci"
  if $? == 0
    update_current
  else
    puts "  - abort"
  end
end

desc "clear all zafu compiled templates"
task :clear_zafu, :roles => :app do
  run "#{in_deploy} rake zena:clear_zafu"
end

desc "clear cache" # temporary rule until cache expire is implemented with a controller
task :clear_zafu, :roles => :app do
  run "#{in_deploy} rake zena:clear_zafu"
end

desc "after code update"
task :after_update_code, :roles => :app do
  symlink
  app_update_symlinks
  clear_zafu
  db_update_config
  migrate
end

desc "after current code update"
task :after_update_current, :roles => :app do
  after_update_code
  restart
end

desc "update symlinks"
task :app_update_symlinks, :roles => :app do
  run "rm -rf #{deploy_to}/current/sites"
  run "ln -sf /var/www/zena #{deploy_to}/current/sites"
  set_permissions
end

desc "migrate database (zena version)"
task :migrate, :roles => :db do
  run "#{in_deploy} rake zena:migrate RAILS_ENV=production"
end

desc "initial app setup"
task :app_setup, :roles => :app do
  run "test -e #{deploy_to}  || mkdir #{deploy_to}"
  run "test -e /var/www/zena || mkdir /var/www/zena"
  setup
end
#========================== MANAGE HOST   =========================#
desc "create a new site"
task :mksite, :roles => :app do
  run "#{in_deploy} rake zena:mksite HOST='#{self[:host]}' PASSWORD='#{self[:password]}' RAILS_ENV=production"
  create_vhost
  set_permissions
end


#========================== MONGREL ===============================#
desc "configure mongrel"
task :mongrel_setup, :roles => :app do
  run "#{in_deploy} mongrel_rails cluster::configure -e production -p #{mongrel_port} -N #{mongrel_count} -c #{deploy_to}/current -a 127.0.0.1 --user www-data --group www-data"
end

desc "Start mongrel"
task :start, :roles => :app do
  run "#{in_deploy} mongrel_rails cluster::start"
end

desc "Restart mongrel"
task :restart, :roles => :app do
  run "#{in_deploy} mongrel_rails cluster::restart"
end

desc "Stop mongrel"
task :stop, :roles => :app do
  run "#{in_deploy} mongrel_rails cluster::stop"
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
  app_setup
  
  db_setup
  
  update_code
  
  mongrel_setup

  apache2_setup
  
  set_permissions

  start
end

desc "Database dump"
task :db_dump, :roles => :db do
  run "cd #{deploy_to} && mysqldump #{db_name} -u root -p > #{db_name}.sql" do |channel, stream, data|
    if data =~ /^Enter password:\s*/m
      logger.info "#{channel[:host]} asked for password"
      channel.send_data "#{password}\n"
    end
    puts data
  end
  run "cd #{deploy_to} && tar czf #{db_name}.sql.tar.gz #{db_name}.sql"
  run "cd #{deploy_to} && rm #{db_name}.sql"
end

# taken from : http://source.mihelac.org/articles/2007/01/11/capistrano-get-method-download-files-from-server
# Get file remote_path from FIRST server targetted by
# the current task and transfer it to local machine as path, SFTP required
def actor.get(remote_path, path, options = {})
  execute_on_servers(options) do |servers|
    self.sessions[servers.first].sftp.connect do |tsftp|
      logger.info "Get #{remote_path} to #{path}" 
      tsftp.get_file remote_path, path
    end
  end
end

desc "Get backup file back"
task :get_backup, :roles => :app do
  get "#{deploy_to}/#{db_name}_data.tar.gz", "./#{db_name}_#{Time.now.strftime '%Y-%m-%d-%H'}.tar.gz"
end

# FIXME: backup not loading data for every site...
desc "Backup all data and bring it backup here"
task :backup, :roles => :app do
  db_dump
  # key track of the current svn revision for app
  
  run "#{in_deploy} svn info > zena_version.txt"
  run "cd #{deploy_to} && tar czf #{db_name}_data.tar.gz #{db_name}.sql.tar.gz data current/zena_version.txt"
  get_backup
end
