
class Employee < ActiveRecord::Base
  include Dynamo::Attribute
  dynamo :first_name, String, :indexed => true, :default=>''
  dynamo :last_name, String, :indexed => true, :default=>''
  dynamo :age, Float
end

class Developer < Employee
  dynamo :language, String
end

class WebDeveloper < Developer

end

class Version < ActiveRecord::Base
  include Dynamo::Attribute
  dynamo 'foo', String
  dynamo 'tic', String
  dynamo 'comment', String
end

begin
  class DynamoMigration < ActiveRecord::Migration
    def self.down
      drop_table "employees"
      drop_table "versions"
    end
    def self.up
      create_table "employees" do |t|
        t.string "type"
        t.text   "dynamo"
      end

      create_table "versions" do |t|
        t.string  "dynamo"
        t.string  "title"
        t.string  "comment"
        t.timestamps
      end

      create_table "dummies" do |t|
        t.text     "dynamo"
      end
    end
  end

  ActiveRecord::Base.establish_connection(:adapter=>'sqlite3', :database=>':memory:')
  ActiveRecord::Migration.verbose = false
  #DynamoMigration.migrate(:down)
  DynamoMigration.migrate(:up)
  ActiveRecord::Migration.verbose = true
end