class RebuildFullpath < ActiveRecord::Migration
  def self.up
    Site.all.each do |site|
      puts "===== rebuilding fullpath for #{site.host} (#{Node.count(:conditions => "site_id = #{site.id}")} nodes)"
      site.rebuild_fullpath
    end
  end

  def self.down
  end
end
