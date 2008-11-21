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