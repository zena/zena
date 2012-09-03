# Passenger deployment recipes
Capistrano::Configuration.instance(:must_exist).load do
  brick_deploy = :passenger

  if self[:app_type] != brick_deploy
    puts %Q{##############################################################################
 ERROR: Loading '#{brick_deploy}' deploy rules when deploying with #{app_type}
        incompatibility between config/bricks.yml (enabled #{brick_deploy} brick) and
        config/deploy.rb (:app_type = #{app_type})
##############################################################################}
  else
    namespace :upload_progress do
      desc "Build and install upload progress extension for Apache2"
      task :setup, :roles => :app do
        tmp_dir = "/tmp/mod_upload_progress.tmp"
        c_file = File.read("#{Zena::ROOT}/vendor/apache2_upload_progress/mod_upload_progress.c")
        run "test -e #{tmp_dir}  || mkdir #{tmp_dir}"
        put c_file, "#{tmp_dir}/mod_upload_progress.c"
        run "cd #{tmp_dir} && apxs2 -c -i -a mod_upload_progress.c && rm -rf #{tmp_dir}"
        run apache2_reload_cmd
      end
    end

    before "zena:setup", "upload_progress:setup"

    namespace :app do

      desc "Restart Passenger app"
      task :restart, :roles => :app do
        stop
        start
      end

      desc "Start Passenger app"
      task :start, :roles => :app do
        run "#{in_current} touch tmp/restart.txt"
      end

      desc "Stop Passenger app (only halt upload DRB)"
      task :stop, :roles => :app do
        # Cannot stop
      end

      desc "Kill Passenger spawner"
      task :kill, :roles => :app do
        run "kill $( passenger-memory-stats | grep 'Passenger spawn server' | awk '{ print $1 }' )"
      end
    end
  end
end