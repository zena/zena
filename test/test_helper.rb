ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'
require File.expand_path(File.dirname(__FILE__) + '/zena_test_unit')
require File.expand_path(File.dirname(__FILE__) + '/zena_test_controller')
require File.expand_path(File.dirname(__FILE__) + '/zena_test_helper')
require 'fileutils'
# load all fixtures and setup fixture_accessors:
FIXTURE_PATH = File.join(File.dirname(__FILE__), 'fixtures')
FILE_FIXTURES_PATH = File.join(File.dirname(__FILE__), 'fixtures', 'files')

# TODO: If you preload your test database with all fixture data (probably in the Rakefile task) and use transactional fixtures, then you may omit all fixtures declarations in your test cases since all the data’s already there and every case rolls back its changes.
class Test::Unit::TestCase
  @@loaded_fixtures = {}
  fixture_table_names = []
  Dir.foreach(FIXTURE_PATH) do |file|
    next unless file =~ /^(.+)\.yml$/
    table_name = $1
    fixture_table_names << table_name
    define_method(table_name) do |fixture|
      if @@loaded_fixtures[table_name][fixture.to_s]
        # allways reload
        @@loaded_fixtures[table_name][fixture.to_s].find
      else
        raise StandardError, "No fixture with name '#{fixture}' found for table '#{table_name}'"
      end
    end
    define_method(table_name + "_id") do |fixture|
      if @@loaded_fixtures[table_name][fixture.to_s]
        @@loaded_fixtures[table_name][fixture.to_s].instance_eval { @fixture['id'].to_i }
      else
        raise StandardError, "No fixture with name '#{fixture}' found for table '#{table_name}'"
      end
    end
  end
  fixtures = Fixtures.create_fixtures(FIXTURE_PATH, fixture_table_names)
  unless fixtures.nil?
    if fixtures.instance_of?(Fixtures)
      @@loaded_fixtures[fixtures.table_name] = fixtures
    else
      fixtures.each { |f| @@loaded_fixtures[f.table_name] = f }
    end
  end
  path =  @@loaded_fixtures['doc_files']['bird_jpg'].instance_eval { @fixture['path'] }
  unless File.exist?("#{RAILS_ROOT}/data/test" + path)
    @@loaded_fixtures['doc_files'].each do |name,fixture|
      path = fixture.instance_eval { @fixture['path'] }.split('/')
      name = path.pop
      FileUtils::mkpath(File.join(RAILS_ROOT,'data', 'test', *path))
      path << name
      FileUtils::cp(File.join(FILE_FIXTURES_PATH,name),File.join(RAILS_ROOT,'data', 'test', *path))
    end
  end
  
  def self.use_transactional_fixtures
    # all subclasses will inherit this setting
    true
  end
  def self.use_instantiated_fixtures
    false
  end
  
  def preserving_files(path, &block)
    path = "/#{path}" unless path[0..0] == '/'
    FileUtils::cp_r("#{RAILS_ROOT}#{path}","#{RAILS_ROOT}#{path}.bak")
    begin
      yield
    ensure
      FileUtils::rmtree("#{RAILS_ROOT}#{path}")
      FileUtils::mv("#{RAILS_ROOT}#{path}.bak","#{RAILS_ROOT}#{path}")
    end
  end
  
  def without_files(path, &block)
    path = "/#{path}" unless path[0..0] == '/'
    FileUtils::mv("#{RAILS_ROOT}#{path}","#{RAILS_ROOT}#{path}.bak")
    begin
      yield
    ensure
      FileUtils::rmtree("#{RAILS_ROOT}#{path}")
      FileUtils::mv("#{RAILS_ROOT}#{path}.bak","#{RAILS_ROOT}#{path}")
    end
  end
end
