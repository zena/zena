# The ThinkingSphinx::Configuration needs RAILS_ROOT and RAILS_ENV in order to function. Only 'setup' needs the
# environment since it needs to get configuration settings from the classes in zena.

namespace :sphinx do
  desc "Create a default configuration file and generate sphinx query"

  setup_done = File.exist?("#{RAILS_ROOT}/config/#{RAILS_ENV}.sphinx.conf")

  task :setup => :environment do
    if File.exist?("#{RAILS_ROOT}/config/sphinx.yml")
      puts "Sphinx searchd: config/sphinx.yml exists, not copying"
    else
      FileUtils.cp(File.join(File.dirname(__FILE__), 'sphinx.yml'), "#{RAILS_ROOT}/config/sphinx.yml")
      puts "Sphinx searchd: created initial config/sphinx.yml"
    end

    sphinx_conf = ThinkingSphinx::Configuration.instance

    FileUtils.mkdir_p sphinx_conf.searchd_file_path
    sphinx_conf.build
    puts "Sphinx searchd: created Sphinx configuration (#{sphinx_conf.config_file})"
  end

  desc "Start a Sphinx searchd daemon using Thinking Sphinx's settings"
  task :start do
    sphinx_conf = ThinkingSphinx::Configuration.instance

    Rake::Task['sphinx:setup'].invoke if !setup_done

    if ThinkingSphinx.sphinx_running?
      puts "Sphinx searchd: already running."
    else
      Dir["#{sphinx_conf.searchd_file_path}/*.spl"].each { |file| File.delete(file) }

      sphinx_conf.controller.start

      if ThinkingSphinx.sphinx_running?
        puts "Sphinx searchd: started successfully (pid #{ThinkingSphinx.sphinx_pid})."
      else
        tail = `tail -n 10 #{sphinx_conf.searchd_log_file.inspect}`
        puts "Sphinx searchd: failed to start.\n#{tail}"
      end
    end
  end

  desc "Stop Sphinx searchd"
  task :stop do
    unless ThinkingSphinx.sphinx_running?
      puts "Sphinx searchd: already stopped."
    else
      ThinkingSphinx::Configuration.instance.controller.stop
      puts "Sphinx searchd: stopped (pid #{ThinkingSphinx.sphinx_pid})."
    end
  end

  desc "Restart Sphinx searchd"
  task :restart do
    Rake::Task['sphinx:stop'].invoke
    sleep(1)
    Rake::Task['sphinx:start'].invoke
  end

  desc "Index data for Sphinx using Thinking Sphinx's settings"
  task :index do

    Rake::Task['sphinx:setup'].invoke if !setup_done

    res = ThinkingSphinx::Configuration.instance.controller.index
    if $? == 0
      puts "Sphinx searchd: successfully indexed data"
    else
      puts "Sphinx searchd: indexing failed\n#{res}"
    end
  end

end