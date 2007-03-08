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
# We use transactional fixtures with a single load for ALL tests (this is not the default rails implementation). Tests are now 5x-10x faster.
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
  
  unless File.exist?("#{RAILS_ROOT}/data/test")
    @@loaded_fixtures['document_contents'].each do |name,fixture|
      path = fixture.instance_eval { [@fixture['ext'],@fixture['version_id'].to_s,@fixture['name']+"."+@fixture['ext']] }
      name = path.pop
      FileUtils::mkpath(File.join(RAILS_ROOT,'data', 'test', *path))
      path << name
      if File.exist?(File.join(FILE_FIXTURES_PATH,name))
        FileUtils::cp(File.join(FILE_FIXTURES_PATH,name),File.join(RAILS_ROOT,'data', 'test', *path))
      end
    end
  end
  
  def self.use_transactional_fixtures
    # all subclasses will inherit this setting
    true
  end
  def self.use_instantiated_fixtures
    false
  end
  
  def setup
  end
  
  def preserving_files(path, &block)
    path = "/#{path}" unless path[0..0] == '/'
    if File.exist?("#{RAILS_ROOT}#{path}")
      FileUtils::cp_r("#{RAILS_ROOT}#{path}","#{RAILS_ROOT}#{path}.bak")
      move_back = true
    else
      move_back = false
    end
    begin
      yield
    ensure
      FileUtils::rmtree("#{RAILS_ROOT}#{path}")
      if move_back
        FileUtils::mv("#{RAILS_ROOT}#{path}.bak","#{RAILS_ROOT}#{path}")
      end
    end
  end
  
  def without_files(path, &block)
    path = "/#{path}" unless path[0..0] == '/'
    if File.exist?("#{RAILS_ROOT}#{path}")
      FileUtils::mv("#{RAILS_ROOT}#{path}","#{RAILS_ROOT}#{path}.bak")
      move_back = true
    else
      move_back = false
    end
    begin
      yield
    ensure
      FileUtils::rmtree("#{RAILS_ROOT}#{path}")
      if move_back
        FileUtils::mv("#{RAILS_ROOT}#{path}.bak","#{RAILS_ROOT}#{path}")
      end
    end
  end
  
  
  # taken from http://manuals.rubyonrails.com/read/chapter/28#page237 with some modifications
  def uploaded_file(fname, content_type="application/octet-stream", filename=nil)
    path = File.join(FILE_FIXTURES_PATH, fname)
    filename ||= File.basename(path)
    # simulate small files with StringIO
    if File.stat(path).size < 1024
      # smaller then 1 Ko
      t = StringIO.new(File.read(path))
    else
      t = Tempfile.new(fname)
      FileUtils.copy_file(path, t.path)
    end
    (class << t; self; end;).class_eval do
      alias local_path path if defined?(:path)
      define_method(:original_filename) { filename }
      define_method(:content_type) { content_type }
    end
    return t
  end

  # JPEG helper
  def uploaded_jpg(fname, filename=nil)
    uploaded_file(fname, 'image/jpeg', filename)
  end

  # PDF helper
  def uploaded_pdf(fname, filename=nil)
    uploaded_file(fname, 'application/pdf', filename)
  end
  
  # TEXT helper
  def uploaded_text(fname, filename=nil)
    uploaded_file(fname, 'text/plain', filename)
  end
  
  # PNG helper
  def uploaded_png(fname, filename=nil)
    uploaded_file(fname, 'image/png', filename)
  end
end
