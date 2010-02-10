
class Employee < ActiveRecord::Base
  include Property
  property 'first_name', String, :indexed => true, :default=>''
  property 'last_name', String, :indexed => true, :default=>''
  property 'age', Float
end

class Developer < Employee
  property 'language', String
end

class WebDeveloper < Developer

end

class Version < ActiveRecord::Base
  attr_accessor :backup
  include Property
  property 'foo', String
  property 'tic', String
  property 'comment', String
end

begin
  class PropertyMigration < ActiveRecord::Migration
    def self.down
      drop_table "employees"
      drop_table "versions"
    end
    def self.up
      create_table "employees" do |t|
        t.string "type"
        t.text   "properties"
      end

      create_table "versions" do |t|
        t.string  "properties"
        t.string  "title"
        t.string  "comment"
        t.timestamps
      end

      create_table "dummies" do |t|
        t.text    "properties"
      end
    end
  end

  ActiveRecord::Base.establish_connection(:adapter=>'sqlite3', :database=>':memory:')
  ActiveRecord::Migration.verbose = false
  #PropertyMigration.migrate(:down)
  PropertyMigration.migrate(:up)
  ActiveRecord::Migration.verbose = true
end