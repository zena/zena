ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'
require File.expand_path(File.dirname(__FILE__) + '/zena_test_unit')
require File.expand_path(File.dirname(__FILE__) + '/zena_test_controller')
require File.expand_path(File.dirname(__FILE__) + '/zena_test_helper')

class Test::Unit::TestCase
  unless methods.include?('o_setup_fixture_accessors')
    instance_eval "alias o_setup_fixture_accessors setup_fixture_accessors"
    def self.setup_fixture_accessors(table_names=nil)
      o_setup_fixture_accessors
      (table_names || fixture_table_names).each do |table_name|
        define_method(table_name + "_id") do |fixture|
          if @loaded_fixtures[table_name][fixture.to_s]
            @loaded_fixtures[table_name][fixture.to_s].find.id
          else
            raise StandardError, "No fixture with name '#{fixture}' found for table '#{table_name}'"
          end
        end
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
