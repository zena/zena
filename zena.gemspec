# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{zena}
  s.version = Zena::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Gaspard Bucher"]
  s.date = %q{2009-09-20}
  s.description = %q{This is a super gem test}
  s.email = %q{gaspard@teti.ch}
  s.extra_rdoc_files = ["History.txt", "README.txt"]
  s.files = (
    ["History.txt", "README.txt", "db/schema.rb", "db/seeds.rb"] +
    ['app', 'bricks', 'db/migrate', 'lib', 'public', 'rails', 'vendor'].map do |d|
      Dir.glob("#{d}/**/*").reject {|path| File.basename(path) =~ /^\./ }
    end
  ).flatten
  s.homepage = %q{http://zenadmin.org}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{zena}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{CMS based on Ruby on Rails with super natural powers}
  s.test_files = Dir.glob("test/**/*").reject {|path| File.basename(path) =~ /^\./ }

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<bones>, [">= 2.5.1"])
    else
      s.add_dependency(%q<bones>, [">= 2.5.1"])
    end
  else
    s.add_dependency(%q<bones>, [">= 2.5.1"])
  end
end
