set :db_name,             "zena"   # If you change this: no dots in this name !
set :server_ip,           nil      # FIXME: set this to your remote server IP in the form: "215.0.0.1"
set :mongrel_port,        "8000"
set :mongrel_count,       "3"
set :db_password,         nil      # FIXME: set password (can be anything).
set :db_user,             "zena"
set :repository,          "http://svn.zenadmin.org/zena/trunk"

if self[:server_ip]
  #================= ADVANCED SETTINGS =============#

  set :deploy_to,    "/var/zena"
  set :zena_sites,   "/var/www/zena"
  set :apache2_vhost_root, "/etc/apache2/sites-available"
  set :apache2_deflate,       true
  set :apache2_debug_deflate, false
  set :apache2_debug_rewrite, false
  set :apache2_static,        []
  set :apache2_reload_cmd, "/etc/init.d/apache2 reload"
  set :debian_host,           true
  set :ssh_user,              "root"

  role :web,         "#{ssh_user}@#{server_ip}"
  role :app,         "#{ssh_user}@#{server_ip}"
  role :db,          "#{ssh_user}@#{server_ip}", :primary => true

  #================= END ADVANCED SETTINGS ==========#
  require 'zena/deploy'

else
  puts <<-TXT
***********************************************************
You should fix your configurations file 'config/deploy.rb'
before running capistrano
***********************************************************
TXT
end

