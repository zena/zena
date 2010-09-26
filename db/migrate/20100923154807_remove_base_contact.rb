class RemoveBaseContact < ActiveRecord::Migration
  extend Zena::Acts::Secure
  TRANSFER_KEYS = %w{first_name name email}

  def self.up
    add_column :sites, :usr_prototype_id, :integer
    rename_column :users, :contact_id, :node_id

    # 0. make sure there is no 'Contact' and 'Reference' roles defined.
    execute "update roles set name='Contact2' where name = 'Contact'"
    execute "update roles set name='Reference2' where name = 'Reference'"

    # Removed class now resolved as vclass
    execute "update nodes set type='Node' where type='Reference' or type='BaseContact'"

    # 1. create a new virtual class 'Contact' with kpath 'NRC'
    Site.all.each do |site|
      Thread.current[:visitor] = User.find(:first, :conditions => ["status = ? AND site_id = ?", User::Status[:admin], site.id])
      ref = secure(VirtualClass) do
        VirtualClass.create(:superclass => 'Node', :name => 'Reference', :create_group_id => site.public_group_id)
      end

      if ref.new_record?
        puts "Could not create 'Reference' virtual class in #{site.host} !"
      else
        execute "UPDATE nodes SET vclass_id = #{ref.id} WHERE kpath = 'NR' AND site_id = #{site.id}"
        contact_class = secure(VirtualClass) do
          VirtualClass.create(:superclass => 'Reference', :name => 'Contact', :create_group_id => site.public_group_id)
        end
        if contact_class.new_record?
          puts "Could not create 'Contact' virtual class in #{site.host} !"
        else
          execute "UPDATE nodes SET vclass_id = #{contact_class.id} WHERE kpath = 'NRC' AND site_id = #{site.id}"
        end
      end

      # Add first_name, name and email to Contact vclass
      TRANSFER_KEYS.each do |key|
        Column.create(:role_id => contact_class.id, :ptype => 'string', :name => key)
      end

      # Move first_name, name, email from User to Contact
      User.find(:all, :conditions => ["site_id = ?", site.id]).each do |user|
        if node = user.node
          node.update_attributes(Hash[*(TRANSFER_KEYS.map {|k| [k, user[k]]}).flatten])
        end
      end
    end

    TRANSFER_KEYS.each do |key|
      remove_column :users, key
    end

    execute "UPDATE sites SET usr_prototype_id = anon_id"
  end

  def self.down
    # Does not rollback content in TRANSFER_KEYS
    TRANSFER_KEYS.each do |key|
      add_column :users, key, :string
    end
    remove_column :sites, :usr_prototype_id
    rename_column :users, :node_id, :contact_id
    contact_ids = VirtualClass.find(:all, :conditions => "type = 'VirtualClass' AND kpath = 'NRC'").map(&:id)
    execute "DELETE FROM columns WHERE role_id IN (#{contact_ids.join(',')})"
    execute "DELETE FROM roles WHERE type = 'VirtualClass' AND (kpath = 'NR' OR kpath = 'NRC')"
    execute "UPDATE nodes SET vclass_id = NULL WHERE kpath = 'NR' OR kpath = 'NRC'"
  end
end
