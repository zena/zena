require 'digest/sha1'
require 'zena/info'
# This is a rails template to generate a basic zena application

run 'rm public/index.html'

gem 'zena', :version => Zena::VERSION
route 'map.zen_routes'

rakefile("zena_tasks.rake") do
<<-TASK
# sync zena tasks to gem version
env = File.read(File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment.rb'))
if env =~ /config.gem.*zena.*version.*'(.*?)'/
  gem 'zena', "= \#{$1}"
end
require 'zena'
require 'tasks/zena'
TASK
end

['development', 'test', 'production'].each do |env|
  environment 'config.action_view.cache_template_loading = false', :env => env
end

inside('app/controllers') do
  app = File.read('application_controller.rb')
  app.gsub!(/class\s+ApplicationController\s+<\s+ActionController::Base/, "class ApplicationController < ActionController::Base\n  include Zena::App")
  app.gsub!(/^(\s+)protect_from_forgery/, '\1# protect_from_forgery')
  File.open('application_controller.rb', 'wb') do |f|
    f.write(app)
  end
end

rake "zena:setup"
rake 'db:create'
rake 'zena:migrate'
rake "zena:mksite HOST='localhost' PASSWORD='admin' LANG='en'"
inside('.') do
  run 'rake zena:migrate RAILS_ENV=production'
  run "rake zena:mksite HOST='localhost' PASSWORD='admin' LANG='en' RAILS_ENV=production"
  run "#{Gem.win_platform? ? 'start' : 'open'} #{File.join(Zena::ROOT, 'lib/zena/deploy/start.html')}"
  exec "script/server -e production -p 3211"
end
