class AddObviousIdx < ActiveRecord::Migration
  INDICES = {
    #:attachments,
    :cached_pages         => %w{node_id},
    :cached_pages_nodes   => %w{node_id cached_page_id},
    :columns              => %w{role_id name},
    :comments             => %w{discussion_id reply_to user_id},
    :data_entries         => DataEntry::NodeLinkSymbolsId,
    :discussions          => %w{node_id},
    :groups_users         => %w{group_id user_id},
    :idx_nodes_ml_strings => %w{value node_id},
    :idx_nodes_strings    => %w{value node_id},
    :idx_templates        => %w{tkpath format mode site_id node_id version_id},
    # :iformats
    :links                => %w{source_id target_id relation_id status date},
    :nodes                => %w{kpath parent_id project_id section_id rgroup_id wgroup_id publish_from},
    :nodes_roles          => %w{node_id role_id},
    :relations            => %w{source_role target_role site_id},
    :roles                => %w{name kpath},
    # :sessions
    :sites                => %w{host},
    # :users
    :versions             => %w{node_id user_id},
    :zips                 => %w{site_id},
  }

  def self.up
    add_index(:nodes, [:zip, :site_id])
    add_index(:idx_nodes_ml_strings, [:node_id, :key, :lang])
    add_index(:idx_nodes_strings, [:node_id, :key])

    INDICES.each do |table, indices|
      indices.each do |key|
        add_index(table, key)
      end
    end


  end

  def self.down
    remove_index(:nodes, :column => [:zip, :site_id])
    remove_index(:idx_nodes_ml_strings, :column => [:node_id, :key, :lang])
    remove_index(:idx_nodes_strings, :column => [:node_id, :key])

    INDICES.each do |table, indices|
      indices.each do |key|
        remove_index(table, key)
      end
    end
  end
end
