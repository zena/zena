class RebuildFullpath < ActiveRecord::Migration
  def self.up
    unless $migrating_new_db
      # Reset column information (used when running all migrations at once)
      [User, Node, Version, Site, Group].each do |klass|
        klass.reset_column_information
      end

      Site.all.each do |site|
        puts "===== rebuilding fullpath for #{site.host} (#{Node.count(:conditions => "site_id = #{site.id}")} nodes)"
        site.rebuild_fullpath
      end
    end
  end

  def self.down
  end
end
