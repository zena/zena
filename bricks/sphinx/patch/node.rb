if errors = Bricks.runtime_requirement_errors('sphinx')
  Node.logger.warn "## search might not work: #{errors.join(', ')}"
  puts "## search might not work: #{errors.join(', ')}"
end

class Node
  include Bricks::Sphinx::NodeSearch
end