# The ThinkingSphinx::Configuration needs RAILS_ROOT and RAILS_ENV in order to function. Only 'setup' needs the
# environment since it needs to get configuration settings from the classes in zena.
require 'tempfile'
require 'yaml'
require 'thinking_sphinx'


class RenderClass
  def initialize(path)
    @text = File.read(path)
  end

  def render(hash)
    @values = hash
    ERB.new(@text).result(binding)
  end

  def method_missing(sym)
    return @values[sym] if @values.has_key?(sym)
    super
  end
end

def render(file, hash)
  RenderClass.new(file).render(hash)
end

namespace :sphinx do
  setup_done = File.exist?("#{RAILS_ROOT}/config/#{RAILS_ENV}.sphinx.conf")

  desc "Create a default configuration file and generate sphinx query"
  task :setup => :environment do
    # TODO: find another way to make sure the models are loaded:
    [Node, Version]

    if File.exist?("#{RAILS_ROOT}/config/sphinx.yml")
      puts "Sphinx searchd: config/sphinx.yml exists, not copying"
    else
      conf = render(File.join(File.dirname(__FILE__), 'sphinx.yml.erb'), :shared_path => File.expand_path(File.join(RAILS_ROOT,'..', '..', 'shared')))
      File.open("#{RAILS_ROOT}/config/sphinx.yml", 'wb') do |f|
        f.puts conf
      end
      puts "Sphinx searchd: created initial config/sphinx.yml"
    end

    sphinx_conf = ThinkingSphinx::Configuration.instance

    # We need this mess because mkdir_p does not properly resolve symlinks
    db_path = sphinx_conf.searchd_file_path
    base = File.dirname(db_path)
    sym_base = `readlink #{base.inspect}`
    if sym_base != '' && $? == 0
      base = sym_base.chomp
    end

    db_path = File.join(base, File.basename(db_path))

    FileUtils.mkdir_p db_path

    sphinx_conf.build
    puts "Sphinx searchd: created Sphinx configuration (#{sphinx_conf.config_file})"
  end

  desc "Create a crontab entry to run the indexer every 30 minutes"
  task :setup_indexer do
    Rake::Task['sphinx:setup'].invoke if !setup_done

    config = YAML.load_file(File.join(RAILS_ROOT, 'config', 'sphinx.yml'))[RAILS_ENV]
    every  = config['run_indexer_at'] || '10,40'
    res = `crontab -l 2>&1`
    if $? != 0 || res =~ /\Acrontab/
      puts "Sphinx indexer: could not access crontab (#{res.chomp})"
    else
      crontab = res.chomp.split("\n")
      res = []
      root = File.expand_path(File.join(RAILS_ROOT, '..', '..', 'current'))
      job = "#{every} *  *   *   *     cd #{root} && /usr/bin/env rake RAILS_ENV=production sphinx:index >> /root/cron.log 2>&1"
      job_inserted = false
      job_action   = 'install'
      crontab.each do |line|
        if line =~ /sphinx:index/
          if !job_inserted
            # update
            res << job
            job_inserted = true
            job_action   = 'update'
          end
        else
          res << line
        end
      end

      if !job_inserted
        # new entry in crontab
        res << job
      end

      tmpf = Tempfile.new('crontab')
      File.open(tmpf.path, 'wb') do |file|
        file.puts res.join("\n")
      end
      user = `whoami`
      res = `crontab -u #{user.chomp} #{tmpf.path}`
      if $? == 0
        puts "Sphinx indexer: cron job #{job_action} ok"
      else
        puts "Sphinx indexer: could not #{job_action} cron job\n#{res}"
      end
    end
  end

  desc "Start a Sphinx searchd daemon using Thinking Sphinx's settings"
  task :start do
    sphinx_conf = ThinkingSphinx::Configuration.instance

    Rake::Task['sphinx:setup'].invoke if !setup_done

    if ThinkingSphinx.sphinx_running?
      puts "Sphinx searchd: already started (pid #{ThinkingSphinx.sphinx_pid})"
    else
      Dir["#{sphinx_conf.searchd_file_path}/*.spl"].each { |file| File.delete(file) }

      sphinx_conf.controller.start

      if ThinkingSphinx.sphinx_running?
        # We need to read the pid file from within Zena application (run under www-data user).
        `chown www-data:www-data #{sphinx_conf.pid_file}`
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