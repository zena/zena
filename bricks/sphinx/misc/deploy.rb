require 'thinking_sphinx/deploy/capistrano'

Capistrano::Configuration.instance(:must_exist).load do
  task :sphinx_stop, :roles => [:app] do
    # stop sphinx search daemon
    run "#{in_current} rake sphinx:stop RAILS_ENV=production"
  end

  task :sphinx_start, :roles => [:app] do
    # make sure sphinx can access the indexes
    sphinx_symlink_indexes
    # make sure a cron indexer is in place
    sphinx_setup_indexer
    # start search daemon
    run "#{in_current} rake sphinx:start RAILS_ENV=production"
  end

  task :sphinx_symlink_indexes, :roles => [:app] do
    run "ln -nfs #{shared_path}/db/sphinx #{current_path}/db/sphinx"
  end

  task :sphinx_setup_indexer, :roles => [:app] do
    # install cron job to rebuild indexes

  end

  # Hook start/stop methods into app start/stop/restart

  on_stop do
    sphinx_stop
  end

  on_start do
    sphinx_start
  end
end
