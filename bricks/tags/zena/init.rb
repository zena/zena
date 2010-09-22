require 'bricks/tags'

unless Node.ancestors.map {|a| a.to_s }.include?('Zena::Use::Relations::ModelMethods')
  raise Exception.new("tags brick depends on 'Zena::Use::Relations'")
end

Node.send(:include, Bricks::Tags)

Link # make sure it is loaded before we reopen it
class Link
  safe_method :name => {:class => String, :nil => true}

  def name
    self[:comment]
  end
end

Node.query_compiler.add_filter_field('tag',
  :key   => 'comment',
  :table => ['tags', 'nodes', 'links', 'TABLE1.id = TABLE2.source_id AND TABLE2.relation_id IS NULL']
)