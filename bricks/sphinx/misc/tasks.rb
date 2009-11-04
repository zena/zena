require 'thinking_sphinx'
require 'thinking_sphinx/tasks'

begin
  require 'thinking_sphinx/deltas/delayed_delta/tasks'
  require 'thinking_sphinx/deltas/delayed_delta' # we need this line for the ts:dd job runner
rescue LoadError
  # no delayed_delta
end

namespace :sphinx do

  desc "Create a default configuration file"
  task :config do
    if File.exist?("#{RAILS_ROOT}/config/sphinx.yml")
      puts "#{RAILS_ROOT}/config/sphinx.yml exists, not copying"
    else
      FileUtils.cp(File.join(File.dirname(__FILE__), 'sphinx.yml'), "#{RAILS_ROOT}/config/sphinx.yml")
    end
  end
end