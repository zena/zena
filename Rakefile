# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require(File.join(File.dirname(__FILE__), 'config', 'boot'))

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

require 'tasks/rails'

# BONES gem management

begin
  require 'bones'
  Bones.setup
rescue LoadError
  begin
    load 'tasks/setup.rb'
  rescue LoadError
    raise RuntimeError, '### please install the "bones" gem ###'
  end
end

ensure_in_path 'lib'
require 'zena'

task :default => 'zena:test'

PROJ.name = 'zena'
PROJ.authors = 'Gaspard Bucher'
PROJ.email = 'gaspard@teti.ch'
PROJ.url = 'http://zenadmin.org'
PROJ.version = Zena::VERSION
PROJ.rubyforge.name = 'zena'

PROJ.spec.opts << '--color'

# EOF
