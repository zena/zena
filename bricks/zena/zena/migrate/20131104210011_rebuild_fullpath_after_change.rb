class RebuildFullpathAfterChange < ActiveRecord::Migration
  def self.up
    Site.master_sites.each do |site|
      site.rebuild_fullpath
    end
  end

  def self.down
  end
end
