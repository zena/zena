require 'thinking_sphinx/deploy/capistrano'

Capistrano::Configuration.instance(:must_exist).load do

  # FIXME: we should find a way to write a clean 'before' hook
  # so that this is simply appeded to existing rules !!
  task :before_update_code, :roles => [:app] do
    thinking_sphinx.stop
  end

  task :after_update_code, :roles => [:app] do
    symlink_sphinx_indexes
    thinking_sphinx.configure
    thinking_sphinx.start
  end

  task :symlink_sphinx_indexes, :roles => [:app] do
    run "ln -nfs #{shared_path}/db/sphinx #{current_path}/db/sphinx"
  end
end