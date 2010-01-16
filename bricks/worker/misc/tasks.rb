
class WorkerCmd
  OK_MESSAGE = {'start' => 'started', 'stop' => 'stopped'}
  def initialize(name, script)
    @name   = name
    @script = script
  end

  def execute(cmd)
    res = `cd #{RAILS_ROOT} && #{@script} RAILS_ENV=#{RAILS_ENV} #{cmd}`
    if $? == 0
      puts "#{@name}: #{OK_MESSAGE[cmd]} (pid #{pid})"
    else
      puts "#{@name}: failed to #{cmd}\n#{res}"
    end
    @pid = nil
  end

  def start
    if running?
      puts "#{@name}: already started (pid #{pid})"
    else
      execute('start')
    end
  end

  def stop
    if !running?
      puts "#{@name}: already stopped"
    else
      execute('stop')
    end
  end

  def pid_file
    @pid_file ||= File.expand_path(File.join(RAILS_ROOT, 'log', "#{@name}.pid"))
  end

  def pid
    @pid ||= File.exists?(pid_file) ? File.read(pid_file)[/\d+/] : nil
  end

  def running?
    pid && Process.kill(0, pid.to_i) rescue false
  end
end


namespace :worker do
  worker = WorkerCmd.new('worker', File.expand_path(File.join(File.dirname(__FILE__), 'worker')))

  desc "Start the delayed jobs worker"
  task :start do
    worker.start
  end

  desc "Stop the delayed jobs worker"
  task :stop do
    worker.stop
  end

  desc "Restart the delayed jobs worker"
  task :restart do
    worker.stop
    sleep(1)
    worker.start
  end
end