unless defined?(Node::HAS_RELATIONS)
  raise Exception.new("tags brick depends on 'has_relations'")
end
Node.send(:has_tags)

class Link
  zafu_readable :name
  
  def name
    self[:comment]
  end
end