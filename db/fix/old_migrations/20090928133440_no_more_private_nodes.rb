class NoMorePrivateNodes < ActiveRecord::Migration
  def self.up
    remove_column :sites, :allow_private
    Site.all.each do |site|
      private_count = Node.count(:conditions => ['site_id = ? AND rgroup_id = 0', site.id])
      if private_count > 0
        puts "===== changing access rights on private nodes for #{site.host} (#{private_count} nodes)"
        # create 'private' group
        private_group = Group.new(:name => '__private')
        private_group[:site_id] = site.id
        private_group.save_with_validation(false)
        if p_id = private_group.id
          execute "UPDATE nodes SET rgroup_id = #{p_id}, wgroup_id = #{p_id}, pgroup_id = #{p_id} WHERE site_id = #{site.id} AND rgroup_id = 0"
          execute "UPDATE nodes SET inherit = 0 WHERE site_id = #{site.id} AND inherit = -1"
        else
          puts "Could not create private group: #{private_group.errors.inspect}"
        end
      end
    end
  end

  def self.down
    create_column :sites, :allow_private, :boolean
  end
end
