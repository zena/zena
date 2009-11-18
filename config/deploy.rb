set :db_name,             "zena"   # If you change this: no dots in this name !
set :server_ip,           3333      # FIXME: set this to your remote server IP in the form: "215.0.0.1"
set :mongrel_port,        "8000"
set :mongrel_count,       "3"
set :db_password,         nil      # FIXME: set password (can be anything).
set :db_user,             "zena"
set :repository,          "http://svn.zenadmin.org/zena/trunk"

if self[:server_ip]
  #================= ADVANCED SETTINGS =============#

  set :deploy_to,    "/var/zena"
  set :sites_root,   "/var/www/zena"
  set :vhost_root,   "/etc/apache2/sites-available"
  set :deflate,       true
  set :debug_deflate, false
  set :debug_rewrite, false
  set :static,        []
  set :apache2_reload_cmd, "/etc/init.d/apache2 reload"
  set :debian_host,           true
  set :ssh_user,              "root"

  role :web,         "#{ssh_user}@#{server_ip}"
  role :app,         "#{ssh_user}@#{server_ip}"
  role :db,          "#{ssh_user}@#{server_ip}", :primary => true

  #================= END ADVANCED SETTINGS ==========#
  # We need to set RAILS_ROOT and RAILS_ENV to know which bricks we need to load, activate
  if !defined?(::RAILS_ROOT)
    ::RAILS_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..'))
  end
  if !defined?(::RAILS_ENV)
    ::RAILS_ENV = 'production'
  end
  require 'zena/deploy'

else
  puts <<-TXT
***********************************************************
You should fix your configurations file 'config/deploy.rb'
before running capistrano
***********************************************************
TXT
end

