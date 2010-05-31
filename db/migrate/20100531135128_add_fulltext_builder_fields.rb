class AddFulltextBuilderFields < ActiveRecord::Migration
  def self.up
    rename_column 'versions', :title, :idx_text_high
    rename_column 'versions', :summary, :idx_text_medium
    rename_column 'versions', :text, :idx_text_low

    add_column 'roles', :idx_text_low, :text
    add_column 'roles', :idx_text_medium, :text
    add_column 'roles', :idx_text_high, :text

    #add_index 'versions', Zena::Use::Fulltext::FULLTEXT_FIELDS, :index_type => "FULLTEXT"
    #remove_index 'versions', %w{title text summary}
  end

  def self.down
    #remove_index 'versions', Zena::Use::Fulltext::FULLTEXT_FIELDS

    rename_column 'versions', :idx_text_high, :title
    rename_column 'versions', :idx_text_medium, :summary
    rename_column 'versions', :idx_text_low, :text

    remove_column 'roles', :idx_text_low
    remove_column 'roles', :idx_text_medium
    remove_column 'roles', :idx_text_high

    #add_index 'versions', %w{title text summary}, :index_type => "FULLTEXT"
  end
end
