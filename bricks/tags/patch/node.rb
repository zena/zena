unless defined?(Node::HAS_RELATIONS)
  raise Exception.new("tags brick depends on 'has_relations'")
end
Node.send(:has_tags)
Link.send(:zafu_readable, :name)

class Link
  def name
    self[:comment]
  end
end

NodeQuery.add_filter_field('tag', :key => 'comment', :table => ['nodes', 'links', 'TABLE1.id = TABLE2.source_id AND TABLE2.relation_id IS NULL'])