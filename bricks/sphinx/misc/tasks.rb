require 'thinking_sphinx/tasks'

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