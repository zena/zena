ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'
require File.expand_path(File.dirname(__FILE__) + '/zena_test_unit')
require File.expand_path(File.dirname(__FILE__) + '/zena_test_controller')
require File.expand_path(File.dirname(__FILE__) + '/zena_test_helper')

# load all fixtures and setup fixture_accessors:


# TODO: If you preload your test database with all fixture data (probably in the Rakefile task) and use transactional fixtures, then you may omit all fixtures declarations in your test cases since all the data’s already there and every case rolls back its changes.
class Test::Unit::TestCase
  @@loaded_fixtures = {}
  fixture_path = File.join(File.dirname(__FILE__), 'fixtures')
  fixture_table_names = []
  Dir.foreach(fixture_path) do |file|
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
  fixtures = Fixtures.create_fixtures(fixture_path, fixture_table_names)
  unless fixtures.nil?
    if fixtures.instance_of?(Fixtures)
      @@loaded_fixtures[fixtures.table_name] = fixtures
    else
      fixtures.each { |f| @@loaded_fixtures[f.table_name] = f }
    end
  end
  
  def self.use_transactional_fixtures
    # all subclasses will inherit this setting
    true
  end
  def self.use_instantiated_fixtures
    false
  end
  
  # taken from http://manuals.rubyonrails.com/read/chapter/28#page237
  # get us an object that represents an uploaded file
  def uploaded_file(path, content_type="application/octet-stream", filename=nil)
    filename ||= File.basename(path)
    t = Tempfile.new(filename)
    FileUtils.copy_file(path, t.path)
    (class << t; self; end;).class_eval do
      alias local_path path
      define_method(:original_filename) { filename }
      define_method(:content_type) { content_type }
    end
    return t
  end

  # a JPEG helper
  def uploaded_jpeg(path, filename=nil)
    uploaded_file(path, 'image/jpeg', filename)
  end

  # a PDF helper
  def uploaded_pdf(path, filename=nil)
    uploaded_file(path, 'application/pdf', filename)
  end
end
