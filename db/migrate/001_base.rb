$password_salt = "fish zen ho"
$su_password = 'su'

class Loader < ActiveRecord::Base
  class << self
    def set_table(tbl)
      set_table_name tbl
      reset_column_information
    end
    def create(opts)
      h = {}
      opts.each_pair do |k,v|
        if :type == k
          h[:_type_] = v
        else
          h[k] = v
        end
      end
      super(h)
    end
  end
  def _type_=(t)
    self.type = t
  end
end

class Base < ActiveRecord::Migration
  
  def self.up
    create_table("addresses", :force => true, :options => 'type=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column "type", :string, :limit => 16
      t.column "created_at", :datetime
      t.column "updated_at", :datetime
      t.column "first_name", :string, :limit => 60
      t.column "name", :string, :limit => 60
      t.column "address", :text
      t.column "zip", :string, :limit => 20
      t.column "city", :string, :limit => 60
      t.column "telephone", :string, :limit => 60
      t.column "mobile", :string, :limit => 60
      t.column "email", :string, :limit => 60
      t.column "item_id", :integer
      t.column "birthday", :date
      t.column "login", :string, :limit => 20
      t.column "password", :string, :limit => 40
      t.column "lang", :string, :limit => 10, :default => "", :null => false
      t.column "password_salt", :string, :limit => 40
    end
      
    create_table("comments", :force => true, :options => 'type=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column "created_at", :datetime
      t.column "updated_at", :datetime
      t.column "version_id", :integer, :default => 0, :null => false
      t.column "version_status", :integer, :default => 0
      t.column "user_id", :integer, :default => 0, :null => false
      t.column "title", :string, :limit => 200, :default => "", :null => false
      t.column "text", :text, :default => "", :null => false
    end

    create_table("contacts_projects", :force => true, :id=>false, :options => 'type=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column "project_id", :integer, :default => 0, :null => false
      t.column "contact_id", :integer, :default => 0, :null => false
    end

    create_table("doc_files", :force => true, :options => 'type=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column "type", :string, :limit => 16
      t.column "version_id", :integer
      t.column "path", :string, :limit => 400, :default => "", :null => false
      t.column "content_type", :string, :limit => 20
      t.column "size", :integer
      t.column "format", :string, :limit => 20
      t.column "width", :integer
      t.column "height", :integer
    end

    create_table("groups", :force => true, :options => 'type=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column "created_at", :datetime
      t.column "updated_at", :datetime
      t.column "name", :string, :limit => 20, :default => "", :null => false
    end
    
    create_table("groups_users", :force => true, :id=>false, :options => 'type=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column "group_id", :integer, :default => 0, :null => false
      t.column "user_id", :integer, :default => 0, :null => false
    end

    create_table("items", :force => true, :options => 'type=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column "type", :string, :limit => 16
      t.column "kpath", :string, :limit => 16
      t.column "created_at", :datetime
      t.column "updated_at", :datetime
      t.column "user_id", :integer, :default => 0, :null => false
      t.column "project_id", :integer
      t.column "parent_id", :integer
      t.column "name", :string, :limit => 200
      t.column "template", :string
      t.column "inherit", :integer
      t.column "rgroup_id", :integer
      t.column "wgroup_id", :integer
      t.column "pgroup_id", :integer
      t.column "publish_from", :datetime
      t.column "max_status", :integer, :default => 30
      t.column "blog_at", :datetime
      t.column "ref_lang", :string, :limit => 10, :default => "", :null => false
      t.column "alias", :string, :limit => 400
      t.column "fullpath", :text
      t.column "address_id", :integer
    end

    create_table("links", :force => true, :options => 'type=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column "source_id", :integer, :default => 0, :null => false
      t.column "target_id", :integer, :default => 0, :null => false
      t.column "role", :string, :limit => 20
    end

    create_table("versions", :force => true, :options => 'type=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column "type", :string, :limit => 16
      t.column "created_at", :datetime
      t.column "updated_at", :datetime
      t.column "item_id", :integer, :default => 0, :null => false
      t.column "user_id", :integer, :default => 0, :null => false
      t.column "lang", :string, :limit => 10, :default => "", :null => false
      t.column "publish_from", :datetime
      t.column "title", :string, :limit => 200, :default => "", :null => false
      t.column "summary", :text, :default => "", :null => false
      t.column "text", :text, :default => "", :null => false
      t.column "cgroup_id", :integer
      t.column "comment", :text, :default => "", :null => false
      t.column "file_ref", :integer
      t.column "status", :integer, :default => 30
      t.column "number", :integer, :default => 1
    end

    create_table("trans_keys", :force => true, :options => 'type=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column "key", :string, :limit => 100, :default => "", :null => false
    end

    create_table("trans_values", :force => true, :options => 'type=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column "key_id", :integer
      t.column "lang", :string, :limit => 10, :default => "", :null => false
      t.column "value", :text, :default => "", :null => false
    end
    
    require 'yaml'
    base_objects = {}
    Dir.foreach(File.dirname(__FILE__)) do |file|
      next unless file =~ /.+\.yml$/
      YAML::load_documents( File.open( File.join(File.dirname(__FILE__), file) ) ) do |doc|
        doc.each do |elem|
          list = elem[1].map do |l|
            hash = {}
            l.each_pair do |k, v|
              hash[k.to_sym] = v
            end
            hash
          end
          tbl = elem[0].to_sym
          if base_objects[tbl]
            base_objects[tbl] += list
          else
            base_objects[tbl] = list
          end
        end
      end
    end

    base_objects.each_pair do |tbl, list|
      Loader.set_table(tbl.to_s)
      list.each do |record|
        if :addresses == tbl
          record[:password] = User.hash_password(record[:password]) if record[:password]
        elsif :items == tbl && record[:blog_at] == 'today'
          record[:blog_at] = Time.now
        end
        unless Loader.create(record)
          puts "could not create #{klass} #{record.inspect}"
        end
      end
    end
  end
  
  def self.down
    drop_table "addresses"
    drop_table "comments"
    drop_table "contacts_projects"
    drop_table "doc_files"
    drop_table "groups"
    drop_table "groups_users"
    drop_table "items"
    drop_table "links"
    drop_table "versions"
    drop_table "trans_keys"
    drop_table "trans_values"
  end
end
