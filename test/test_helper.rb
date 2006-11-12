ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'
require File.expand_path(File.dirname(__FILE__) + '/testcase_unit')
require File.expand_path(File.dirname(__FILE__) + '/testcase_controller')
require File.expand_path(File.dirname(__FILE__) + '/testcase_helper')

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
end
