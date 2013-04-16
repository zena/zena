require 'digest/sha1'
require 'zena/info'
# This is a rails template to generate a basic zena application

if RUBY_PLATFORM =~ /mswin32/
  run "del public\\index.html"
else
  run "rm public/index.html"
end

gem 'zena', :version => Zena::VERSION
route 'map.zen_routes'

rakefile("zena_tasks.rake") do
<<-TASK
# sync zena tasks to gem version
env = File.read(File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment.rb'))
if env =~ /^\\s*(#|).*config.gem.*zena.*version.*'(.*?)'/
  if $1 == '#'
    # commented out
  else
    gem 'zena', "= \#{$2}"
  end
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

rake 'zena:assets OVERWRITE_ASSETS=true'
rake 'zena:fix_rakefile'
