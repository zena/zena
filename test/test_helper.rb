ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'
require File.expand_path(File.dirname(__FILE__) + '/testcase_unit')
require File.expand_path(File.dirname(__FILE__) + '/testcase_controller')
require File.expand_path(File.dirname(__FILE__) + '/testcase_helper')

class Test::Unit::TestCase
  # UNCOMMENT THE FOLLOWING LINES IF YOU GET NoMethodError: undefined method `items_id'
  # OR PATCH active_record/fixtures.rb with http://dev.rubyonrails.org/attachment/ticket/4877/find_fixture_id_by_name.diff
  unless methods.include?('o_setup_fixture_accessors')
    instance_eval "alias o_setup_fixture_accessors setup_fixture_accessors"
    def self.setup_fixture_accessors(table_names=nil)
      o_setup_fixture_accessors
      (table_names || fixture_table_names).each do |table_name|
        table_name = table_name.to_s.tr('.','_')

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
  fixtures :addresses, :groups, :groups_users, :items, :versions, :trans, :trans_values
  
  # Transactional fixtures accelerate your tests by wrapping each test method
  # in a transaction that's rolled back on completion.  This ensures that the
  # test database remains unchanged so your fixtures don't have to be reloaded
  # between every test method.  Fewer database queries means faster tests.
  #
  # Read Mike Clark's excellent walkthrough at
  #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
  #
  # Every Active Record database supports transactions except MyISAM tables
  # in MySQL.  Turn off transactional fixtures in this case; however, if you
  # don't care one way or the other, switching from MyISAM to InnoDB tables
  # is recommended.
  self.use_transactional_fixtures = true

  # Instantiated fixtures are slow, but give you @david where otherwise you
  # would need people(:david).  If you don't want to migrate your existing
  # test cases which use the @david style and don't mind the speed hit (each
  # instantiated fixtures translates to a database query per test method),
  # then set this back to true.
  self.use_instantiated_fixtures  = false

  # Add more helper methods to be used by all tests here...
end
