unless defined?(Node.ancestors.include?('Zena::Use::RelationsImpl::ClassMethods')) # FIXME: not sure here
  raise Exception.new("tags brick depends on 'use_relations'")
end
Node.send(:has_tags)
Link.send(:attr_public, :name)

class Link
  def name
    self[:comment]
  end
end

NodeQuery.add_filter_field('tag', :key => 'comment', :table => ['nodes', 'links', 'TABLE1.id = TABLE2.source_id AND TABLE2.relation_id IS NULL'])