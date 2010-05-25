class MoveTagIntoVclass < ActiveRecord::Migration
  def self.up
    if !$migrating_new_site
      # create a new virtual class for each site and assign all tags to this class.
      Site.find(:all).each do |site|
        VirtualClass.connection.execute("INSERT INTO virtual_classes (`name`,`kpath`,`real_class`,`icon`,`allowed_attributes`,`create_group_id`,`site_id`) VALUES ('Tag','NPT','Page',NULL,NULL,#{site[:site_group_id]},#{site[:id]})")
        vclass = VirtualClass.find(:first, :conditions=>["site_id = ? AND kpath = 'NPT'",site[:id]])
        Node.connection.execute "UPDATE nodes SET vclass_id = #{vclass[:id]} WHERE kpath = 'NPT'"
      end
    end
  end

  def self.down
  end
end
