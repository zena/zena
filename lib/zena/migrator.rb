module Zena
  class Migrator < ActiveRecord::Migrator
    class << self
      
      def migrate(migrations_path, brick_name, target_version = nil)
        case
          when target_version.nil?              then up(migrations_path, brick_name, target_version)
          when current_version(brick_name) > target_version then down(migrations_path, brick_name, target_version)
          else                                       up(migrations_path, brick_name, target_version)
        end
      end

      def up(migrations_path, brick_name, target_version = nil)
        self.new(:up, migrations_path, brick_name, target_version).migrate
      end

      def down(migrations_path, brick_name, target_version = nil)
        self.new(:down, migrations_path, brick_name, target_version).migrate
      end

      def bricks_info_table_name
        ActiveRecord::Base.table_name_prefix + "bricks_info" + ActiveRecord::Base.table_name_suffix
      end
      
      def get_all_versions(brick_name)
        ActiveRecord::Base.connection.select_values("SELECT version FROM #{bricks_info_table_name} WHERE brick = '#{brick_name}'").map(&:to_i).sort
      end
      
      
      def current_version(brick_name)
        sm_table = bricks_info_table_name
        if ActiveRecord::Base.connection.table_exists?(sm_table)
          get_all_versions(brick_name).max || 0
        else
          0
        end
      end

      def init_bricks_migration_table
        begin
          ActiveRecord::Base.connection.execute "CREATE TABLE #{bricks_info_table_name} (version #{ActiveRecord::Base.connection.type_to_sql(:integer)}, brick #{ActiveRecord::Base.connection.type_to_sql(:string)})"
        rescue ActiveRecord::StatementInvalid
          # Schema has been intialized
        end
      end
    end
    
    def initialize(direction, migrations_path, brick_name, target_version = nil)
      raise StandardError.new("This database does not yet support migrations") unless ActiveRecord::Base.connection.supports_migrations?
      self.class.init_bricks_migration_table
      @direction, @migrations_path, @brick_name, @target_version = direction, migrations_path, brick_name, target_version      
    end
    
    def migrated
      @migrated_versions ||= self.class.get_all_versions(@brick_name)
    end

    private
      def record_version_state_after_migrating(version)
        sm_table = self.class.bricks_info_table_name

        @migrated_versions ||= []
        if down?
          @migrated_versions.delete(version.to_i)
          ActiveRecord::Base.connection.update("DELETE FROM #{sm_table} WHERE version = '#{version}' AND brick = '#{@brick_name}'")
        else
          @migrated_versions.push(version.to_i).sort!
          ActiveRecord::Base.connection.insert("INSERT INTO #{sm_table} (version, brick) VALUES ('#{version}','#{@brick_name}')")
        end
      end
  end
end
