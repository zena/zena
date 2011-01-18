class Base < ActiveRecord::Migration
  def self.up
    create_table "attachments", :force => true do |t|
      t.string   "filename"
      t.integer  "site_id"
      t.integer  "user_id"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "cached_pages", :force => true do |t|
      t.text     "path"
      t.datetime "expire_after"
      t.datetime "created_at"
      t.integer  "node_id"
      t.integer  "site_id"
    end

    add_index "cached_pages", ["node_id"], :name => "index_cached_pages_on_node_id"

    create_table "cached_pages_nodes", :id => false, :force => true do |t|
      t.integer "cached_page_id"
      t.integer "node_id"
    end

    add_index "cached_pages_nodes", ["node_id"], :name => "index_cached_pages_nodes_on_node_id"
    add_index "cached_pages_nodes", ["cached_page_id"], :name => "index_cached_pages_nodes_on_cached_page_id"

    create_table "caches", :force => true do |t|
      t.datetime "updated_at"
      t.integer  "visitor_id"
      t.string   "visitor_groups", :limit => 200
      t.string   "kpath",          :limit => 200
      t.text     "content"
      t.integer  "site_id"
      t.integer  "context"
    end

    create_table "columns", :force => true do |t|
      t.integer  "role_id"
      t.string   "name"
      t.string   "ptype"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "site_id"
      t.string   "index",      :limit => 30
    end

    add_index "columns", ["role_id"], :name => "index_columns_on_role_id"
    add_index "columns", ["name"], :name => "index_columns_on_name"

    create_table "comments", :force => true do |t|
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "status",                       :default => 70, :null => false
      t.integer  "discussion_id"
      t.integer  "reply_to"
      t.integer  "user_id"
      t.string   "title",         :limit => 250, :default => "", :null => false
      t.text     "text",                                         :null => false
      t.string   "author_name",   :limit => 300
      t.integer  "site_id"
      t.string   "ip",            :limit => 200
    end

    add_index "comments", ["discussion_id"], :name => "index_comments_on_discussion_id"
    add_index "comments", ["reply_to"], :name => "index_comments_on_reply_to"
    add_index "comments", ["user_id"], :name => "index_comments_on_user_id"

    create_table "contact_contents", :force => true do |t|
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "version_id"
      t.string   "first_name", :limit => 60,  :default => "", :null => false
      t.string   "name",       :limit => 60,  :default => "", :null => false
      t.text     "address"
      t.string   "zip",        :limit => 20,  :default => "", :null => false
      t.string   "city",       :limit => 60,  :default => "", :null => false
      t.string   "telephone",  :limit => 60,  :default => "", :null => false
      t.string   "mobile",     :limit => 60,  :default => "", :null => false
      t.string   "email",      :limit => 60,  :default => "", :null => false
      t.date     "birthday"
      t.integer  "site_id"
      t.string   "country",    :limit => 100
    end

    create_table "data_entries", :force => true do |t|
      t.integer  "site_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "user_id"
      t.datetime "date"
      t.text     "text"
      t.decimal  "value_a",    :precision => 24, :scale => 8
      t.integer  "node_a_id"
      t.integer  "node_b_id"
      t.integer  "node_c_id"
      t.integer  "node_d_id"
      t.decimal  "value_b",    :precision => 24, :scale => 8
    end

    add_index "data_entries", ["node_a_id"], :name => "index_data_entries_on_node_a_id"
    add_index "data_entries", ["node_b_id"], :name => "index_data_entries_on_node_b_id"
    add_index "data_entries", ["node_c_id"], :name => "index_data_entries_on_node_c_id"
    add_index "data_entries", ["node_d_id"], :name => "index_data_entries_on_node_d_id"

    create_table "discussions", :force => true do |t|
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "node_id"
      t.boolean  "inside",                   :default => false
      t.boolean  "open",                     :default => true
      t.string   "lang",       :limit => 10, :default => "",    :null => false
      t.integer  "site_id"
    end

    add_index "discussions", ["node_id"], :name => "index_discussions_on_node_id"

    create_table "document_contents", :force => true do |t|
      t.string  "type",         :limit => 32
      t.integer "version_id"
      t.string  "name",         :limit => 200, :default => "", :null => false
      t.string  "content_type", :limit => 40
      t.string  "ext",          :limit => 20
      t.integer "size"
      t.integer "width"
      t.integer "height"
      t.integer "site_id"
      t.text    "exif_json"
    end

    create_table "groups", :force => true do |t|
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "name",       :limit => 20, :default => "", :null => false
      t.integer  "site_id"
    end

    create_table "groups_users", :id => false, :force => true do |t|
      t.integer "group_id", :null => false
      t.integer "user_id",  :null => false
    end

    add_index "groups_users", ["group_id"], :name => "index_groups_users_on_group_id"
    add_index "groups_users", ["user_id"], :name => "index_groups_users_on_user_id"

    create_table "idx_nodes_datetimes", :force => true do |t|
      t.integer  "node_id", :null => false
      t.string   "key"
      t.datetime "value"
    end

    add_index "idx_nodes_datetimes", ["node_id", "key"], :name => "index_idx_nodes_datetimes_on_node_id_and_key"
    add_index "idx_nodes_datetimes", ["value"], :name => "index_idx_nodes_datetimes_on_value"
    add_index "idx_nodes_datetimes", ["node_id"], :name => "index_idx_nodes_datetimes_on_node_id"

    create_table "idx_nodes_floats", :force => true do |t|
      t.integer "node_id", :null => false
      t.string  "key"
      t.float   "value"
    end

    add_index "idx_nodes_floats", ["node_id", "key"], :name => "index_idx_nodes_floats_on_node_id_and_key"
    add_index "idx_nodes_floats", ["value"], :name => "index_idx_nodes_floats_on_value"
    add_index "idx_nodes_floats", ["node_id"], :name => "index_idx_nodes_floats_on_node_id"

    create_table "idx_nodes_integers", :force => true do |t|
      t.integer "node_id", :null => false
      t.string  "key"
      t.integer "value"
    end

    add_index "idx_nodes_integers", ["node_id", "key"], :name => "index_idx_nodes_integers_on_node_id_and_key"
    add_index "idx_nodes_integers", ["value"], :name => "index_idx_nodes_integers_on_value"
    add_index "idx_nodes_integers", ["node_id"], :name => "index_idx_nodes_integers_on_node_id"

    create_table "idx_nodes_ml_strings", :force => true do |t|
      t.integer "node_id",               :null => false
      t.string  "key"
      t.string  "lang",    :limit => 10
      t.string  "value"
    end

    add_index "idx_nodes_ml_strings", ["node_id", "key", "lang"], :name => "index_idx_nodes_ml_strings_on_node_id_and_key_and_lang"
    add_index "idx_nodes_ml_strings", ["value"], :name => "index_idx_nodes_ml_strings_on_value"
    add_index "idx_nodes_ml_strings", ["node_id"], :name => "index_idx_nodes_ml_strings_on_node_id"

    create_table "idx_nodes_strings", :force => true do |t|
      t.integer "node_id", :null => false
      t.string  "key"
      t.string  "value"
    end

    add_index "idx_nodes_strings", ["node_id", "key"], :name => "index_idx_nodes_strings_on_node_id_and_key"
    add_index "idx_nodes_strings", ["value"], :name => "index_idx_nodes_strings_on_value"
    add_index "idx_nodes_strings", ["node_id"], :name => "index_idx_nodes_strings_on_node_id"

    create_table "idx_projects", :force => true do |t|
      t.integer  "site_id"
      t.integer  "node_id"
      t.integer  "blog_id"
      t.string   "blog_title"
      t.integer  "contact_id"
      t.string   "contact_first_name"
      t.string   "contact_name"
      t.integer  "reference_id"
      t.string   "reference_name"
      t.string   "reference_title"
      t.integer  "tag_id"
      t.datetime "tag_created_at"
      t.string   "tag_title"
    end

    create_table "idx_templates", :force => true do |t|
      t.integer "site_id"
      t.integer "node_id"
      t.string  "format"
      t.string  "tkpath"
      t.string  "mode"
      t.integer "version_id"
      t.integer "skin_id"
    end

    add_index "idx_templates", ["tkpath"], :name => "index_idx_templates_on_tkpath"
    add_index "idx_templates", ["format"], :name => "index_idx_templates_on_format"
    add_index "idx_templates", ["mode"], :name => "index_idx_templates_on_mode"
    add_index "idx_templates", ["site_id"], :name => "index_idx_templates_on_site_id"
    add_index "idx_templates", ["node_id"], :name => "index_idx_templates_on_node_id"
    add_index "idx_templates", ["version_id"], :name => "index_idx_templates_on_version_id"

    create_table "iformats", :force => true do |t|
      t.string   "name",       :limit => 40
      t.integer  "site_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "size"
      t.integer  "gravity"
      t.integer  "width"
      t.integer  "height"
      t.string   "popup",      :limit => 120
    end

    create_table "links", :force => true do |t|
      t.integer  "source_id"
      t.integer  "target_id"
      t.integer  "relation_id"
      t.integer  "status"
      t.string   "comment",     :limit => 60
      t.datetime "date"
    end

    add_index "links", ["source_id"], :name => "index_links_on_source_id"
    add_index "links", ["target_id"], :name => "index_links_on_target_id"
    add_index "links", ["relation_id"], :name => "index_links_on_relation_id"
    add_index "links", ["status"], :name => "index_links_on_status"
    add_index "links", ["date"], :name => "index_links_on_date"

    create_table "nodes", :force => true do |t|
      t.string   "type",          :limit => 32
      t.datetime "event_at"
      t.string   "kpath",         :limit => 16
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "user_id",                                         :null => false
      t.integer  "section_id"
      t.integer  "parent_id"
      t.integer  "inherit"
      t.integer  "rgroup_id"
      t.integer  "wgroup_id"
      t.integer  "dgroup_id"
      t.datetime "publish_from"
      t.datetime "log_at"
      t.string   "ref_lang",      :limit => 10,  :default => "",    :null => false
      t.string   "alias",         :limit => 400
      t.text     "fullpath"
      t.boolean  "custom_base",                  :default => false
      t.text     "basepath"
      t.integer  "site_id"
      t.integer  "zip"
      t.integer  "project_id"
      t.float    "position",                     :default => 0.0
      t.integer  "vclass_id"
      t.integer  "custom_a"
      t.integer  "custom_b"
      t.text     "vhash"
      t.integer  "skin_id"
      t.string   "_id",           :limit => 40
      t.datetime "idx_datetime1"
      t.datetime "idx_datetime2"
      t.float    "idx_float1"
      t.float    "idx_float2"
      t.string   "idx_string1"
      t.string   "idx_string2"
      t.integer  "idx_integer1"
      t.integer  "idx_integer2"
    end

    add_index "nodes", ["zip", "site_id"], :name => "index_nodes_on_zip_and_site_id"
    add_index "nodes", ["kpath"], :name => "index_nodes_on_kpath"
    add_index "nodes", ["parent_id"], :name => "index_nodes_on_parent_id"
    add_index "nodes", ["project_id"], :name => "index_nodes_on_project_id"
    add_index "nodes", ["section_id"], :name => "index_nodes_on_section_id"
    add_index "nodes", ["rgroup_id"], :name => "index_nodes_on_rgroup_id"
    add_index "nodes", ["wgroup_id"], :name => "index_nodes_on_wgroup_id"
    add_index "nodes", ["publish_from"], :name => "index_nodes_on_publish_from"
    add_index "nodes", ["site_id"], :name => "index_nodes_on_site_id"
    add_index "nodes", ["idx_datetime1"], :name => "index_nodes_on_idx_datetime1"
    add_index "nodes", ["idx_datetime2"], :name => "index_nodes_on_idx_datetime2"
    add_index "nodes", ["idx_float1"], :name => "index_nodes_on_idx_float1"
    add_index "nodes", ["idx_float2"], :name => "index_nodes_on_idx_float2"
    add_index "nodes", ["idx_string1"], :name => "index_nodes_on_idx_string1"
    add_index "nodes", ["idx_string2"], :name => "index_nodes_on_idx_string2"
    add_index "nodes", ["idx_integer1"], :name => "index_nodes_on_idx_integer1"
    add_index "nodes", ["idx_integer2"], :name => "index_nodes_on_idx_integer2"

    create_table "nodes_roles", :id => false, :force => true do |t|
      t.integer "node_id", :default => 0, :null => false
      t.integer "role_id", :default => 0, :null => false
    end

    add_index "nodes_roles", ["node_id"], :name => "index_nodes_roles_on_node_id"
    add_index "nodes_roles", ["role_id"], :name => "index_nodes_roles_on_role_id"

    create_table "relations", :force => true do |t|
      t.string  "source_role",   :limit => 32
      t.string  "source_kpath",  :limit => 16
      t.boolean "source_unique"
      t.string  "source_icon",   :limit => 200
      t.string  "target_role",   :limit => 32
      t.string  "target_kpath",  :limit => 16
      t.boolean "target_unique"
      t.string  "target_icon",   :limit => 200
      t.integer "site_id",                      :null => false
      t.string  "rel_group"
    end

    add_index "relations", ["source_role"], :name => "index_relations_on_source_role"
    add_index "relations", ["target_role"], :name => "index_relations_on_target_role"
    add_index "relations", ["site_id"], :name => "index_relations_on_site_id"

    create_table "roles", :force => true do |t|
      t.string   "name"
      t.string   "kpath",                  :limit => 16
      t.string   "real_class",             :limit => 16
      t.string   "icon",                   :limit => 200
      t.integer  "create_group_id"
      t.integer  "site_id",                               :null => false
      t.boolean  "auto_create_discussion"
      t.string   "type",                   :limit => 32
      t.datetime "created_at"
      t.datetime "updated_at"
      t.text     "properties"
      t.string   "idx_class",              :limit => 30
      t.string   "idx_scope"
    end

    add_index "roles", ["name"], :name => "index_roles_on_name"
    add_index "roles", ["kpath"], :name => "index_roles_on_kpath"
    add_index "roles", ["site_id"], :name => "index_roles_on_site_id"

    create_table "sessions", :force => true do |t|
      t.string   "session_id", :null => false
      t.text     "data"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"
    add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"

    create_table "sites", :force => true do |t|
      t.string   "host"
      t.integer  "root_id"
      t.integer  "anon_id"
      t.integer  "public_group_id"
      t.integer  "site_group_id"
      t.string   "name"
      t.boolean  "authentication"
      t.string   "languages"
      t.string   "default_lang"
      t.boolean  "http_auth"
      t.boolean  "auto_publish"
      t.integer  "redit_time"
      t.datetime "formats_updated_at"
      t.text     "properties"
      t.integer  "api_group_id"
      t.datetime "roles_updated_at"
    end

    add_index "sites", ["host"], :name => "index_sites_on_host"

    create_table "stored_columns", :force => true do |t|
      t.integer "stored_role_id"
      t.string  "name"
      t.string  "ptype"
    end

    create_table "users", :force => true do |t|
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "login",               :limit => 20
      t.string   "crypted_password",    :limit => 40
      t.string   "time_zone"
      t.integer  "site_id"
      t.integer  "status"
      t.integer  "node_id"
      t.string   "lang",                :limit => 10, :default => "", :null => false
      t.string   "persistence_token"
      t.string   "password_salt"
      t.string   "single_access_token"
      t.text     "properties"
    end

    create_table "versions", :force => true do |t|
      t.string   "type",            :limit => 32
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "node_id",                                               :null => false
      t.integer  "user_id",                                               :null => false
      t.string   "lang",            :limit => 10,         :default => "", :null => false
      t.datetime "publish_from"
      t.text     "comment"
      t.text     "idx_text_high"
      t.text     "idx_text_medium"
      t.text     "idx_text_low"
      t.integer  "status",                                                :null => false
      t.integer  "number",                                :default => 1,  :null => false
      t.integer  "content_id"
      t.integer  "site_id"
      t.text     "properties",      :limit => 2147483647
      t.integer  "attachment_id"
    end

    add_index "versions", ["node_id"], :name => "index_versions_on_node_id"
    add_index "versions", ["user_id"], :name => "index_versions_on_user_id"
    if Zena::Db.adapter == 'mysql'
      execute "ALTER TABLE versions ENGINE = MyISAM"
      execute "CREATE FULLTEXT INDEX index_versions_on_title_and_text_and_summary ON versions (idx_text_high,idx_text_low,idx_text_medium)"
    end

    create_table "zips", :id => false, :force => true do |t|
      t.integer "site_id"
      t.integer "zip"
    end

    add_index "zips", ["site_id"], :name => "index_zips_on_site_id"
  end

  def self.down
    drop_table "attachments"
    drop_table "cached_pages"
    drop_table "cached_pages_nodes"
    drop_table "caches"
    drop_table "columns"
    drop_table "comments"
    drop_table "contact_contents"
    drop_table "data_entries"
    drop_table "discussions"
    drop_table "document_contents"
    drop_table "groups"
    drop_table "groups_users"
    drop_table "idx_nodes_datetimes"
    drop_table "idx_nodes_floats"
    drop_table "idx_nodes_integers"
    drop_table "idx_nodes_ml_strings"
    drop_table "idx_nodes_strings"
    drop_table "idx_projects"
    drop_table "idx_templates"
    drop_table "iformats"
    drop_table "links"
    drop_table "nodes"
    drop_table "nodes_roles"
    drop_table "relations"
    drop_table "roles"
    drop_table "sessions"
    drop_table "sites"
    drop_table "stored_columns"
    drop_table "users"
    drop_table "versions"
    drop_table "zips"
  end
end
