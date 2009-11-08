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
PROJ.readme_file = 'README.rdoc'

PROJ.spec.opts << '--color'
reject_paths = File.read(File.join(File.dirname(__FILE__),'.gitignore')).map do |git_ignore_path|
  %r{#{git_ignore_path.chomp.gsub('.', '\\.').gsub('*', '.*')}}
end

PROJ.gem.files = (
  ['History.txt', 'README.rdoc', 'db/schema.rb'] +
  ['app', 'bin', 'bricks', 'config', 'db', 'lib', 'locale', 'public', 'rails', 'vendor', 'test'].map do |d|
    Dir.glob("#{d}/**/*").reject do |path|
      File.basename(path) =~ /^\./ || !reject_paths.map { |regexp| regexp =~ path ? true : nil}.compact.empty?
    end
  end
).flatten

Zena.gem_configuration.each do |gem_name, gem_config|
  if gem_config
    if gem_config['development_only']
      PROJ.gem.development_dependencies << [gem_name, [gem_config['version']]]
    else
      PROJ.gem.dependencies << [gem_name, [gem_config['version']]]
    end
  else
    PROJ.gem.dependencies << [gem_name]
  end
end
# EOF
