require 'thinking_sphinx/deploy/capistrano'

Capistrano::Configuration.instance(:must_exist).load do

  task :worker_stop, :roles => [:app] do
    # stop delayed job worker
    run "#{in_current} rake RAILS_ENV=production worker:stop"
  end

  on_stop do
    worker_stop
  end

  task :worker_start, :roles => [:app] do
    # start delayed job worker
    run "#{in_current} rake RAILS_ENV=production worker:start"
  end

  on_start do
    worker_start
  end
end
