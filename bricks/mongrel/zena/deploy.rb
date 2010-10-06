Capistrano::Configuration.instance(:must_exist).load do
  brick_deploy = :mongrel
  if self[:app_type] != brick_deploy
    puts %Q{##############################################################################
 ERROR: Loading '#{brick_deploy}' deploy rules when deploying with #{app_type}
        incompatibility between config/bricks.yml (enabled #{brick_deploy} brick) and
        config/deploy.rb (:app_type = #{app_type})
##############################################################################}
  else
    #========================== MONGREL ===============================#
    namespace :app do

      desc "configure mongrel"
      task :configure, :roles => :app do
        if Zena::ASSET_PORT == self[:mongrel_port].to_i - 1
          mongrel_port  = Zena::ASSET_PORT
          mongrel_count = self[:mongrel_count] + 1
        elsif Zena::ASSET_PORT.nil?
          # no asset port: OK.
        else
          raise "Invalid asset_port setting in bricks.yml: the port should be equal to mongrel_port minus one. (expected #{self[:mongrel_port].to_i - 1}, found #{Zena::ASSET_PORT})"
        end

        run "#{in_current} mongrel_rails cluster::configure -e production -p #{mongrel_port} -N #{mongrel_count} -c #{deploy_to}/current -P log/mongrel.pid -l log/mongrel.log -a 127.0.0.1 --user www-data --group www-data"
        run "#{in_current} echo 'config_script: config/mongrel_upload_progress.conf' >> config/mongrel_cluster.yml"
      end

      desc "Stop the drb upload_progress server"
      task :upload_progress_stop , :roles => :app do
        run "#{in_current} ruby lib/upload_progress_server.rb stop"
      end

      desc "Start the drb upload_progress server"
      task :upload_progress_start , :roles => :app do
        run "#{in_current} lib/upload_progress_server.rb start"
      end

      desc "Restart the upload_progress server"
      task :upload_progress_restart, :roles => :app do
        upload_progress_stop
        upload_progress_start
      end

      desc "Restart mongrels"
      task :restart, :roles => :app do
        stop
        start
      end

      desc "Start mongrels"
      task :start, :roles => :app do
        configure
        upload_progress_start
        run "#{in_current} mongrel_rails cluster::start"
      end

      desc "Stop mongrels"
      task :stop, :roles => :app do
        configure
        upload_progress_stop
        run "#{in_current} mongrel_rails cluster::stop"
      end
    end
  end
end