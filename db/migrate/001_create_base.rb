class CreateBase < ActiveRecord::Migration
  
  def self.up
    create_table("users", :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column "created_at", :datetime
      t.column "updated_at", :datetime
      t.column "login", :string, :limit => 20
      t.column "password", :string, :limit => 40
      t.column "lang", :string, :limit => 10, :default => "", :null => false
      t.column "contact_id", :integer
      t.column "first_name", :string, :limit => 60 # cached from contact_content
      t.column "name", :string, :limit => 60       # cached from contact_content
      t.column "email", :string, :limit => 60      # cached from contact_content
    end
      
    create_table("contact_contents", :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column "created_at", :datetime
      t.column "updated_at", :datetime
      t.column "version_id", :integer
      t.column "first_name", :string, :limit => 60, :default => "", :null => false
      t.column "name", :string, :limit => 60, :default => "", :null => false
      t.column "address", :text, :default => "", :null => false
      t.column "zip", :string, :limit => 20, :default => "", :null => false
      t.column "city", :string, :limit => 60, :default => "", :null => false
      t.column "telephone", :string, :limit => 60, :default => "", :null => false
      t.column "mobile", :string, :limit => 60, :default => "", :null => false
      t.column "email", :string, :limit => 60, :default => "", :null => false
      t.column "birthday", :date
    end

    create_table("document_contents", :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column "type", :string, :limit => 32
      t.column "version_id", :integer
      t.column "name", :string, :limit => 200, :default => "", :null => false
      t.column "content_type", :string, :limit => 20
      t.column "ext", :string, :limit=>20
      t.column "size", :integer
      # NOT USED ? t.column "format", :string, :limit => 20
      t.column "width", :integer
      t.column "height", :integer
    end

    create_table("groups", :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column "created_at", :datetime
      t.column "updated_at", :datetime
      t.column "name", :string, :limit => 20, :default => "", :null => false
    end
    
    create_table("groups_users", :id=>false, :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column "group_id", :integer, :default => 0, :null => false
      t.column "user_id", :integer, :default => 0, :null => false
    end

    create_table("nodes", :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column "type", :string, :limit => 32
      t.column "event_at", :datetime
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
      t.column "log_at", :datetime
      t.column "ref_lang", :string, :limit => 10, :default => "", :null => false
      t.column "alias", :string, :limit => 400
      t.column "fullpath", :text
    end

    create_table("links", :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column "source_id", :integer, :default => 0, :null => false
      t.column "target_id", :integer, :default => 0, :null => false
      t.column "role", :string, :limit => 20
    end

    create_table("versions", :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column "type", :string, :limit => 32
      t.column "created_at", :datetime
      t.column "updated_at", :datetime
      t.column "node_id", :integer, :default => 0, :null => false
      t.column "user_id", :integer, :default => 0, :null => false
      t.column "lang", :string, :limit => 10, :default => "", :null => false
      t.column "publish_from", :datetime
      t.column "comment", :text, :default => "", :null => false
      t.column "title", :string, :limit => 200, :default => "", :null => false
      t.column "summary", :text, :default => "", :null => false
      t.column "text", :text, :default => "", :null => false
      t.column "status", :integer, :default => 30
      t.column "number", :integer, :default => 1
      t.column "content_id", :integer
    end

    create_table("discussions", :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column "created_at", :datetime
      t.column "updated_at", :datetime
      t.column "node_id", :integer
      t.column "inside", :boolean, :default=>false  # if true, the discussion will not appear when published but when proposed or redaction
      t.column "open", :boolean, :default=>true
      t.column "lang", :string, :limit => 10, :default => "", :null => false
    end

    create_table("comments", :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column "created_at", :datetime
      t.column "updated_at", :datetime
      t.column "status", :integer
      t.column "discussion_id", :integer
      t.column "reply_to", :integer
      t.column "user_id", :integer
      t.column "title", :string, :limit => 250, :default => "", :null => false
      t.column "text", :text, :default => "", :null => false
      t.column "author_name",:string, :limit => 300
    end
    
    create_table("trans_phrases", :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column "phrase", :string, :limit => 100, :default => "", :null => false
    end

    create_table("trans_values", :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column "phrase_id", :integer
      t.column "lang", :string, :limit => 10, :default => "", :null => false
      t.column "value", :text, :default => "", :null => false
    end
    
    create_table("caches", :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column "updated_at", :datetime
      t.column "visitor_id", :integer
      t.column "visitor_groups", :string, :limit => 200
      t.column "kpath", :string, :limit => 200
      t.column "context", :string, :limit => 200
      t.column "content", :text
    end
  end
  
  def self.down
    drop_table "users"
    drop_table "contact_contents"
    drop_table "document_contents"
    drop_table "groups"
    drop_table "groups_users"
    drop_table "nodes"
    drop_table "links"
    drop_table "versions"
    drop_table "trans_phrases"
    drop_table "trans_values"
    drop_table "caches"
    drop_table "comments"
    drop_table "discussions"
  end
end