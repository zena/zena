ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'
require File.expand_path(File.dirname(__FILE__) + '/testcase_unit')
require File.expand_path(File.dirname(__FILE__) + '/testcase_controller')
require File.expand_path(File.dirname(__FILE__) + '/testcase_helper')

class Test::Unit::TestCase
  # the following hacks loads all the fixtures only once and is a MASSIVE speed improvement.
  unless methods.include?('o_setup_fixture_accessors')
    instance_eval "alias o_setup_fixture_accessors setup_fixture_accessors"
    def self.setup_fixture_accessors(table_names=nil)
      o_setup_fixture_accessors
      (table_names || fixture_table_names).each do |table_name|
        table_name = table_name.to_s.tr('.','_')
  
        define_method(table_name + "_id") do |fixture|
          if loaded_fixtures[table_name][fixture.to_s]
            loaded_fixtures[table_name][fixture.to_s].find.id
          else
            raise StandardError, "No fixture with name '#{fixture}' found for table '#{table_name}'"
          end
        end
      end
    end
    def loaded_fixtures
      unless @@already_loaded_fixtures[Test::Unit::TestCase]    
        @loaded_fixtures = {}
        fixtures = Fixtures.create_fixtures(Test::Unit::TestCase.fixture_path, Test::Unit::TestCase.fixture_table_names, Test::Unit::TestCase.fixture_class_names)
        unless fixtures.nil?
          if fixtures.instance_of?(Fixtures)
            @loaded_fixtures[fixtures.table_name] = fixtures
          else
            fixtures.each { |f| @loaded_fixtures[f.table_name] = f }
          end
        end
        @@already_loaded_fixtures[Test::Unit::TestCase] = @loaded_fixtures
      end
      @@already_loaded_fixtures[Test::Unit::TestCase]
    end
  end
  def self.use_transactional_fixtures
    # all subclasses will inherit this setting
    true
  end
  fixtures :versions, :comments, :items, :addresses, :groups_users, :trans_keys, :trans_values
end
