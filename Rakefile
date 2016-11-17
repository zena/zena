# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require(File.join(File.dirname(__FILE__), 'config', 'boot'))

require 'rake'
require 'rake/testtask'

require 'tasks/rails'

task :default => 'zena:test'

require 'zena'

# GEM management
# begin
#   require 'jeweler'
#   Jeweler::Tasks.new do |gemspec|
#     gemspec.name = 'zena'
#     gemspec.summary = 'CMS with super natural powers, based on Ruby on Rails'
#     gemspec.description = "zena is a Ruby on Rails  CMS (content management system) with a focus on usability, ease of customization and web 2.0 goodness (application like behaviour)."
#     gemspec.email = "gaspard@teti.ch"
#     gemspec.homepage = "http://zenadmin.org"
#     gemspec.authors = ['Gaspard Bucher']
#     gemspec.version = Zena::VERSION
#     gemspec.rubyforge_project = 'zena'

#     gemspec.files.exclude 'config/routes.rb'
#     gemspec.files.exclude %r{^vendor/plugins/selenium-on-rails}
#     gemspec.files.exclude %r{vendor/TextMate}


#     # Gem dependecies
#     Zena.gem_configuration.each do |gem_name, gem_config|
#       if gem_config
#         next if gem_config['optional']
#         if gem_config['development_only']
#           gemspec.add_development_dependency(gem_name, gem_config['version'])
#         else
#           gemspec.add_dependency(gem_name, gem_config['version'])
#         end
#       else
#         gemspec.add_dependency(gem_name)
#       end
#     end
#   end
# rescue LoadError
#   puts "Jeweler not available. Gem packaging tasks not available."
# end
