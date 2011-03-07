# This migration should be run in the 0.x branch with:
# 1. all brickes turned to OFF (important)
# 2. YOU *MUST* alter schema migrations before running this
# DelayedJobs migration not taken into account here.
class Zerox1Schema < ActiveRecord::Migration
  def self.up
    $Zerox1SchemaRunning = true

    if connection.tables.include?('idx_templates')
      # New app based on 1.0: do nothing
      puts "=>  Detected 1.0+ schema: not running Zerox1Schema."
      return
    end

    table_options = Zena::Db.table_options

    # ============================================ access_hits
    # removed in cleanup migration

    # ============================================ attachments

    create_table "attachments", :options => table_options, :force => true do |t|
      t.string   "filename"
      t.integer  "site_id"
      t.integer  "user_id"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    # ============================================ cached_pages
    execute "ALTER TABLE cached_pages COLLATE utf8_unicode_ci"
    execute "ALTER TABLE cached_pages MODIFY path TEXT COLLATE utf8_unicode_ci"
    add_index "cached_pages", ["node_id"], :name => "index_cached_pages_on_node_id"

    # ============================================ cached_pages_nodes
    execute "ALTER TABLE cached_pages_nodes COLLATE utf8_unicode_ci"
    add_index "cached_pages_nodes", ["node_id"], :name => "index_cached_pages_nodes_on_node_id"
    add_index "cached_pages_nodes", ["cached_page_id"], :name => "index_cached_pages_nodes_on_cached_page_id"

    # ============================================ caches
    execute "ALTER TABLE caches COLLATE utf8_unicode_ci"
    execute "ALTER TABLE caches MODIFY visitor_groups VARCHAR(200) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE caches MODIFY kpath VARCHAR(200) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE caches MODIFY content TEXT COLLATE utf8_unicode_ci"

    # ============================================ comments
    create_table "columns", :options => table_options, :force => true do |t|
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

    # ============================================ comments
    execute "ALTER TABLE comments COLLATE utf8_unicode_ci"
    execute "ALTER TABLE comments MODIFY title VARCHAR(250) COLLATE utf8_unicode_ci NOT NULL DEFAULT ''"
    execute "ALTER TABLE comments MODIFY `text` TEXT COLLATE utf8_unicode_ci NOT NULL"
    execute "ALTER TABLE comments MODIFY author_name VARCHAR(300) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE comments MODIFY ip VARCHAR(200) COLLATE utf8_unicode_ci DEFAULT NULL"

    add_index "comments", ["discussion_id"], :name => "index_comments_on_discussion_id"
    add_index "comments", ["reply_to"], :name => "index_comments_on_reply_to"
    add_index "comments", ["user_id"], :name => "index_comments_on_user_id"

    # ============================================ contact_contents
    # content migrated in zero99_to_one

    # ============================================ data_entries
    execute "ALTER TABLE data_entries COLLATE utf8_unicode_ci"
    execute "ALTER TABLE data_entries MODIFY `text` TEXT COLLATE utf8_unicode_ci"

    add_index "data_entries", ["node_a_id"], :name => "index_data_entries_on_node_a_id"
    add_index "data_entries", ["node_b_id"], :name => "index_data_entries_on_node_b_id"
    add_index "data_entries", ["node_c_id"], :name => "index_data_entries_on_node_c_id"
    add_index "data_entries", ["node_d_id"], :name => "index_data_entries_on_node_d_id"

    # ============================================ delayed_jobs
    # ignore

    # ============================================ discussions
    execute "ALTER TABLE discussions COLLATE utf8_unicode_ci"
    execute "ALTER TABLE discussions MODIFY `lang` VARCHAR(10) COLLATE utf8_unicode_ci NOT NULL DEFAULT ''"

    add_index "discussions", ["node_id"], :name => "index_discussions_on_node_id"

    # ============================================ document_contents
    # content migrated in zero99_to_one

    # ============================================ form_lines
    # removed in cleanup migration

    # ============================================ form_seizures
    # removed in cleanup migration

    # ============================================ groups
    execute "ALTER TABLE groups COLLATE utf8_unicode_ci"
    execute "ALTER TABLE groups MODIFY `name` VARCHAR(20) COLLATE utf8_unicode_ci NOT NULL DEFAULT ''"

    # ============================================ groups_users
    execute "ALTER TABLE groups_users COLLATE utf8_unicode_ci"
    execute "ALTER TABLE groups_users MODIFY `group_id` INT(11) NOT NULL"
    execute "ALTER TABLE groups_users MODIFY `user_id` INT(11) NOT NULL"

    add_index "groups_users", ["group_id"], :name => "index_groups_users_on_group_id"
    add_index "groups_users", ["user_id"], :name => "index_groups_users_on_user_id"

    # ============================================ dyn_attributes
    # content migrated in zero99_to_one

    # ============================================ idx_...
    create_table "idx_nodes_datetimes", :options => table_options, :force => true do |t|
      t.integer  "node_id", :null => false
      t.string   "key"
      t.datetime "value"
    end

    add_index "idx_nodes_datetimes", ["node_id", "key"], :name => "index_idx_nodes_datetimes_on_node_id_and_key"
    add_index "idx_nodes_datetimes", ["value"], :name => "index_idx_nodes_datetimes_on_value"
    add_index "idx_nodes_datetimes", ["node_id"], :name => "index_idx_nodes_datetimes_on_node_id"

    create_table "idx_nodes_floats", :options => table_options, :force => true do |t|
      t.integer "node_id", :null => false
      t.string  "key"
      t.float   "value"
    end

    add_index "idx_nodes_floats", ["node_id", "key"], :name => "index_idx_nodes_floats_on_node_id_and_key"
    add_index "idx_nodes_floats", ["value"], :name => "index_idx_nodes_floats_on_value"
    add_index "idx_nodes_floats", ["node_id"], :name => "index_idx_nodes_floats_on_node_id"

    create_table "idx_nodes_integers", :options => table_options, :force => true do |t|
      t.integer "node_id", :null => false
      t.string  "key"
      t.integer "value"
    end

    add_index "idx_nodes_integers", ["node_id", "key"], :name => "index_idx_nodes_integers_on_node_id_and_key"
    add_index "idx_nodes_integers", ["value"], :name => "index_idx_nodes_integers_on_value"
    add_index "idx_nodes_integers", ["node_id"], :name => "index_idx_nodes_integers_on_node_id"

    create_table "idx_nodes_ml_strings", :options => table_options, :force => true do |t|
      t.integer "node_id",               :null => false
      t.string  "key"
      t.string  "lang",    :limit => 10
      t.string  "value"
    end

    add_index "idx_nodes_ml_strings", ["node_id", "key", "lang"], :name => "index_idx_nodes_ml_strings_on_node_id_and_key_and_lang"
    add_index "idx_nodes_ml_strings", ["value"], :name => "index_idx_nodes_ml_strings_on_value"
    add_index "idx_nodes_ml_strings", ["node_id"], :name => "index_idx_nodes_ml_strings_on_node_id"

    create_table "idx_nodes_strings", :options => table_options, :force => true do |t|
      t.integer "node_id", :null => false
      t.string  "key"
      t.string  "value"
    end

    add_index "idx_nodes_strings", ["node_id", "key"], :name => "index_idx_nodes_strings_on_node_id_and_key"
    add_index "idx_nodes_strings", ["value"], :name => "index_idx_nodes_strings_on_value"
    add_index "idx_nodes_strings", ["node_id"], :name => "index_idx_nodes_strings_on_node_id"

    # This is just for testing...
    create_table "idx_projects", :options => table_options, :force => true do |t|
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

    create_table "idx_templates", :options => table_options, :force => true do |t|
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

    # ============================================ template_contents
    # content migrated in zero99_to_one

    # ============================================ iformats
    execute "ALTER TABLE iformats COLLATE utf8_unicode_ci"
    execute "ALTER TABLE iformats MODIFY `name`  VARCHAR(40) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE iformats MODIFY `popup` VARCHAR(120) COLLATE utf8_unicode_ci DEFAULT NULL"

    # ============================================ links
    execute "ALTER TABLE links COLLATE utf8_unicode_ci"
    execute "ALTER TABLE links MODIFY `comment` VARCHAR(60) COLLATE utf8_unicode_ci DEFAULT NULL"

    add_index "links", ["source_id"], :name => "index_links_on_source_id"
    add_index "links", ["target_id"], :name => "index_links_on_target_id"
    add_index "links", ["relation_id"], :name => "index_links_on_relation_id"
    add_index "links", ["status"], :name => "index_links_on_status"
    add_index "links", ["date"], :name => "index_links_on_date"


    # ============================================ nodes
    execute "ALTER TABLE nodes COLLATE utf8_unicode_ci"
    execute "ALTER TABLE nodes MODIFY `type` VARCHAR(32) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE nodes MODIFY `kpath` VARCHAR(16) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE nodes MODIFY `user_id` INT(11) NOT NULL"
    execute "ALTER TABLE nodes MODIFY `ref_lang` VARCHAR(10) COLLATE utf8_unicode_ci NOT NULL DEFAULT ''"
    execute "ALTER TABLE nodes MODIFY `vhash` TEXT COLLATE utf8_unicode_ci"
    execute "ALTER TABLE nodes MODIFY `fullpath` TEXT COLLATE utf8_unicode_ci"
    execute "ALTER TABLE nodes MODIFY `basepath` TEXT COLLATE utf8_unicode_ci"
    # new
    add_column :nodes, 'skin_id', :integer
    add_column :nodes, "_id"            , :string   , :limit => 40
    add_column :nodes, "idx_datetime1"  , :datetime
    add_column :nodes, "idx_datetime2"  , :datetime
    add_column :nodes, "idx_float1"     , :float
    add_column :nodes, "idx_float2"     , :float
    add_column :nodes, "idx_string1"    , :string
    add_column :nodes, "idx_string2"    , :string
    add_column :nodes, "idx_integer1"   , :integer
    add_column :nodes, "idx_integer2"   , :integer

    # idx
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

    # ============================================ nodes_roles
    create_table "nodes_roles", :id => false, :force => true do |t|
      t.integer "node_id", :default => 0, :null => false
      t.integer "role_id", :default => 0, :null => false
    end

    add_index "nodes_roles", ["node_id"], :name => "index_nodes_roles_on_node_id"
    add_index "nodes_roles", ["role_id"], :name => "index_nodes_roles_on_role_id"

    # ============================================ relations
    execute "ALTER TABLE relations COLLATE utf8_unicode_ci"
    execute "ALTER TABLE relations MODIFY `source_role` VARCHAR(32) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE relations MODIFY `source_kpath` VARCHAR(16) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE relations MODIFY `source_icon` VARCHAR(200) COLLATE utf8_unicode_ci DEFAULT NULL"

    execute "ALTER TABLE relations MODIFY `target_role` VARCHAR(32) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE relations MODIFY `target_kpath` VARCHAR(16) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE relations MODIFY `target_icon` VARCHAR(200) COLLATE utf8_unicode_ci DEFAULT NULL"

    add_column :relations, :rel_group, :string

    add_index "relations", ["source_role"], :name => "index_relations_on_source_role"
    add_index "relations", ["target_role"], :name => "index_relations_on_target_role"
    add_index "relations", ["site_id"], :name => "index_relations_on_site_id"

    # ============================================ roles (virtual_classes)
    execute "RENAME TABLE virtual_classes TO roles"
    execute "ALTER TABLE roles COLLATE utf8_unicode_ci"
    execute "ALTER TABLE roles MODIFY `name` VARCHAR(255) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE roles MODIFY `kpath` VARCHAR(16) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE roles MODIFY `real_class` VARCHAR(16) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE roles MODIFY `icon` VARCHAR(200) COLLATE utf8_unicode_ci DEFAULT NULL"
    # new
    add_column :roles, :type, :string
    add_column :roles, :created_at, :datetime
    add_column :roles, :updated_at, :datetime
    add_column :roles, :idx_class, :string, :limit => 30
    add_column :roles, :idx_scope, :string, :limit => 255

    # idx
    add_index "roles", ["name"], :name => "index_roles_on_name"
    add_index "roles", ["kpath"], :name => "index_roles_on_kpath"
    add_index "roles", ["site_id"], :name => "index_roles_on_site_id"

    # ============================================ schema_migrations
    execute "ALTER TABLE schema_migrations COLLATE utf8_unicode_ci"
    execute "ALTER TABLE schema_migrations MODIFY `version` VARCHAR(255) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE schema_migrations MODIFY `brick` VARCHAR(255) COLLATE utf8_unicode_ci DEFAULT NULL"

    # ============================================ sessions
    execute "ALTER TABLE sessions COLLATE utf8_unicode_ci"
    execute "ALTER TABLE sessions MODIFY `session_id` VARCHAR(255) COLLATE utf8_unicode_ci NOT NULL"
    execute "ALTER TABLE sessions MODIFY `data` TEXT COLLATE utf8_unicode_ci NOT NULL"

    # ============================================ sites
    execute "ALTER TABLE sites COLLATE utf8_unicode_ci"
    execute "ALTER TABLE sites MODIFY `host` VARCHAR(255) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE sites MODIFY `host` VARCHAR(255) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE sites MODIFY `name` VARCHAR(255) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE sites MODIFY `languages` VARCHAR(255) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE sites MODIFY `default_lang` VARCHAR(255) COLLATE utf8_unicode_ci DEFAULT NULL"

    remove_column :sites, :su_id
    add_column :sites, :properties,       :text
    add_column :sites, :api_group_id,     :integer
    add_column :sites, :roles_updated_at, :datetime

    add_index "sites", ["host"], :name => "index_sites_on_host"

    # ============================================ stored_columns
    create_table "stored_columns", :force => true do |t|
      t.integer "stored_role_id"
      t.string  "name"
      t.string  "ptype"
    end

    # ============================================ users
    execute "ALTER TABLE users COLLATE utf8_unicode_ci"
    execute "ALTER TABLE users MODIFY `login` VARCHAR(20) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE users MODIFY `crypted_password` VARCHAR(40) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE users MODIFY `time_zone` VARCHAR(255) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE users MODIFY `lang` VARCHAR(10) COLLATE utf8_unicode_ci NOT NULL DEFAULT ''"
    execute "ALTER TABLE users MODIFY `password_salt` VARCHAR(255) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE users MODIFY `persistence_token` VARCHAR(255) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE users MODIFY `single_access_token` VARCHAR(255) COLLATE utf8_unicode_ci DEFAULT NULL"

    rename_column :users, :contact_id, :node_id

    add_column :users, :properties, :text

    # ============================================ versions
    execute "DROP INDEX index_versions_on_title_and_text_and_summary ON versions" rescue nil
    execute "ALTER TABLE versions ENGINE=InnoDB COLLATE utf8_unicode_ci"
    execute "ALTER TABLE versions MODIFY `type` VARCHAR(32) COLLATE utf8_unicode_ci DEFAULT NULL"
    execute "ALTER TABLE versions MODIFY `node_id` INT(11) NOT NULL"
    execute "ALTER TABLE versions MODIFY `user_id` INT(11) NOT NULL"
    execute "ALTER TABLE versions MODIFY `lang` VARCHAR(10) COLLATE utf8_unicode_ci NOT NULL DEFAULT ''"
    
    # Version is not inherited anymore
    remove_column(:versions, :type) rescue nil

    remove_index  :versions, :column => [:title, :text, :summary]

    execute "ALTER TABLE versions MODIFY `comment` TEXT COLLATE utf8_unicode_ci"

    rename_column :versions, :title, :idx_text_high
    execute "ALTER TABLE versions MODIFY `idx_text_high` TEXT COLLATE utf8_unicode_ci"

    rename_column :versions, :summary, :idx_text_medium
    execute "ALTER TABLE versions MODIFY `idx_text_medium` TEXT COLLATE utf8_unicode_ci"

    rename_column :versions, :text, :idx_text_low
    execute "ALTER TABLE versions MODIFY `idx_text_low` TEXT COLLATE utf8_unicode_ci"

    execute "ALTER TABLE versions MODIFY `status` INT(11) NOT NULL"

    # LONGTEXT
    add_column :versions, :properties,    :text, :limit => 2147483647
    add_column :versions, :attachment_id, :integer

    add_index "versions", ["node_id"], :name => "index_versions_on_node_id"
    add_index "versions", ["user_id"], :name => "index_versions_on_user_id"

    # ============================================ zips
    execute "ALTER TABLE zips COLLATE utf8_unicode_ci"

    add_index "zips", ["site_id"], :name => "index_zips_on_site_id"
  end
end