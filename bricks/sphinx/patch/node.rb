if error = Bricks::Patcher.setup_valid?('sphinx')
  puts "## search might not work: #{error}"
end

class Node
  include Bricks::Sphinx::NodeSearch
end