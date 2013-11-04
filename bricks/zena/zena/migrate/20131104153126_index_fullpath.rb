class IndexFullpath < ActiveRecord::Migration
  def self.up                                                             
    # 255 length = InnoDB limit
    add_index "nodes", ["fullpath", "site_id"], :name => "index_on_fullpath_and_site_id", :length => {"fullpath"=>"255", "site_id"=>nil}
  end

  def self.down
    remove_index  :nodes, :column => ['fullpath', 'site_id']
  end
end
