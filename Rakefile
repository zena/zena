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
PROJ.gem.files = (
  ['History.txt', 'README.txt', 'db/schema.rb'] +
  ['app', 'bricks', 'db/migrate', 'lib', 'locale', 'public', 'rails', 'vendor'].map do |d|
    Dir.glob("#{d}/**/*").reject {|path| File.basename(path) =~ /^\./ }
  end
).flatten

PROJ.gem.dependencies += [
  ['RedCloth',             ['= 3.0.4']   ],
  ['gettext',              ['= 1.93.0']  ],
  ['grosser-fast_gettext', ['~> 0.4.16'] ],
  ['hpricot'                             ],
  ['mislav-will_paginate', ['~> 2.2.3']  ],
  ['querybuilder',         ['= 0.5.5']   ],
  ['ruby-recaptcha',       ['= 1.0.0']   ],
  ['syntax',               ['= 1.0.0']   ],
  ['tzinfo',               ['= 0.3.12']  ],
  ['uuidtools',            ['= 2.0.0']   ]
]
PROJ.gem.development_dependencies += [
  ['yamltest',             ['= 0.5.3']   ],
]
# EOF
