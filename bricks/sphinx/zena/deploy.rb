require 'thinking_sphinx/deploy/capistrano'

Capistrano::Configuration.instance(:must_exist).load do
  task :sphinx_stop, :roles => [:app] do
    # stop sphinx search daemon
    run "#{in_current} rake RAILS_ENV=production sphinx:stop"
  end

  task :sphinx_start, :roles => [:app] do
    # make sure sphinx can access the indexes
    sphinx_symlink_indexes
    # make sure a cron indexer is in place
    sphinx_setup_indexer
    # start search daemon
    run "#{in_current} rake RAILS_ENV=production sphinx:start"
  end

  task :sphinx_symlink_indexes, :roles => [:app] do
    run "test -e #{shared_path}/db || mkdir #{shared_path}/db"
    run "test -e #{shared_path}/db/sphinx || mkdir #{shared_path}/db/sphinx"
    run "ln -nfs #{shared_path}/db/sphinx #{current_path}/db/sphinx"
  end

  task :sphinx_setup, :roles => [:app] do
    # setup sphinx
    run "#{in_current} rake RAILS_ENV=production sphinx:setup"
  end

  task :sphinx_index, :roles => [:app] do
    # rebuild sphinx index now
    run "#{in_current} rake RAILS_ENV=production sphinx:index"
  end

  task :sphinx_setup_indexer, :roles => [:app] do
    # install cron job to rebuild indexes
    run "#{in_current} rake RAILS_ENV=production sphinx:setup_indexer"
  end

  # Hook start/stop methods into app start/stop/restart

  on_stop do
    sphinx_stop
  end

  on_start do
    sphinx_start
  end
end
