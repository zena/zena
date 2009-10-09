class AddVhashInNode < ActiveRecord::Migration
  def self.up
    add_column :nodes, :vhash, :text
    Site.all.each do |site|
      puts "===== rebuilding vhash for #{site.host} (#{Node.count(:conditions => "site_id = #{site.id}")} nodes)"
      site.rebuild_vhash
    end
  end

  def self.down
    remove_column :nodes, :vhash
  end
end
