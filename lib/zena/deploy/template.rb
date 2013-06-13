require 'digest/sha1'
require 'zena/info'
# This is a rails template to generate a basic zena application

if RUBY_PLATFORM =~ /mswin32/
  run "del public\\index.html"
else
  run "rm public/index.html"
end

gem 'zena', :version => Zena::VERSION
route '# Insert custom routes here.'
route ''
route 'map.zen_routes'
route ''
route '# Routes below this are never reached.'

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
  File.open('application_controller.rb', 'wb') do |f|
    f.write %q{
  # Filters added to this controller apply to all controllers in the application.
  # Likewise, all the methods added will be available for all controllers.

  class ApplicationController < ActionController::Base
    include Zena::App
    helper :all # include all helpers, all the time
    # protect_from_forgery # See ActionController::RequestForgeryProtection for details
  end
}
  end
end

rake 'zena:assets OVERWRITE_ASSETS=true'
rake 'zena:fix_rakefile'
