module Zena
  class Migrator < ActiveRecord::Migrator
    class << self
      def migrate(migrations_path, brick_name, target_version = nil)
        self.init_bricks_migration_table
        case
        when target_version.nil?, current_version(brick_name) < target_version
          up(migrations_path, brick_name, target_version)
        when current_version(brick_name) > target_version
          down(migrations_path, brick_name, target_version)
        when current_version(brick_name) == target_version
          return # You're on the right version
        end
      end

      def up(migrations_path, brick_name, target_version = nil)
        self.new(:up, migrations_path, brick_name, target_version).migrate
      end

      def down(migrations_path, brick_name, target_version = nil)
        self.new(:down, migrations_path, brick_name, target_version).migrate
      end

      def bricks_info_table_name
        Base.table_name_prefix + "bricks_info" + Base.table_name_suffix
      end

      def current_version(brick_name)
        begin
          ActiveRecord::Base.connection.select_one("SELECT version FROM #{bricks_info_table_name} WHERE brick = '#{brick_name}'")["version"].to_i
        rescue
          ActiveRecord::Base.connection.execute "INSERT INTO #{bricks_info_table_name} (brick, version) VALUES('#{brick_name}',0)"
          0
        end
      end

      def init_bricks_migration_table
        begin
          ActiveRecord::Base.connection.execute "CREATE TABLE #{bricks_info_table_name} (version #{Base.connection.type_to_sql(:integer)}, brick #{Base.connection.type_to_sql(:string)})"
        rescue ActiveRecord::StatementInvalid
          # Schema has been intialized
        end
      end
    end

    def initialize(direction, migrations_path, brick_name, target_version = nil)
      raise StandardError.new("This database does not yet support migrations") unless Base.connection.supports_migrations?
      @direction, @migrations_path, @brick_name, @target_version = direction, migrations_path, brick_name, target_version
      self.class.init_bricks_migration_table
    end

    def current_version
      self.class.current_version(@brick_name)
    end

    private

    def set_schema_version(version)
      Base.connection.update("UPDATE #{self.class.bricks_info_table_name} SET version = #{down? ? version.to_i - 1 : version.to_i} WHERE brick = '#{@brick_name}'")
    end
  end
end
