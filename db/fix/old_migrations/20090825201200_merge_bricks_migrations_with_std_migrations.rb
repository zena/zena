class BricksMergerModel < ActiveRecord::Base
  set_table_name Zena::Migrator.old_bricks_info_table_name
end

class MergeBricksMigrationsWithStdMigrations < ActiveRecord::Migration
  def self.up
    if ActiveRecord::Base.connection.tables.include?(Zena::Migrator.old_bricks_info_table_name)
      # merge content from 'bricks_info' in
      schema_table_name = ActiveRecord::Migrator.schema_migrations_table_name
      BricksMergerModel.find(:all).each do |r|
        execute "INSERT INTO #{schema_table_name} (brick,version) VALUES (#{r.brick.inspect}, #{r.version.inspect})"
      end
      drop_table :bricks_info
    end
  end

  def self.down
  end
end
