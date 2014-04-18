if errors = Bricks.runtime_requirement_errors('sphinx')
  Node.logger.warn "## search might not work: #{errors.join(', ')}"
  puts "## search might not work: #{errors.join(', ')}"
end

Node.send(:include, Bricks::Sphinx::NodeSearch)

# add 'sphinx match xxxx' to QueryNode
Node.query_compiler.add_fulltext_field('sphinx') do |processor, table, right|
  helper = processor.instance_variable_get(:@rubyless_helper)
  case right[0]
  when :string, :dstring, :real, :integer
    value = RubyLess.translate_string(helper, right[1])
  when :rubyless
    value = RubyLess.translate(helper, right[1])
  else
    raise ::QueryBuilder::Error.new("Can only match against literal or rubyless values.")
  end
  "#{table}.id IN (#{processor.send(:insert_bind, "Node.search_for_ids(#{value})")})"
end