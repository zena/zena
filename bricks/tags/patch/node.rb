unless defined?(Node.ancestors.include?('Zena::Use::Relations::ClassMethods')) # FIXME: not sure here
  raise Exception.new("tags brick depends on 'Zena::Use::Relations'")
end
Node.send(:has_tags)

Link # make sure it is loaded before we reopen it
class Link
  safe_method :name => {:class => String, :nil => true}
  safe_method :count => {:class => Number, :nil => true}

  def name
    self[:comment]
  end

  def count
    self[:count]
  end
end

Zena::Use::QueryNode.add_filter_field('tag', :key => 'comment', :table => ['nodes', 'links', 'TABLE1.id = TABLE2.source_id AND TABLE2.relation_id IS NULL'])