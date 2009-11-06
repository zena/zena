unless error = Bricks::Patcher.setup_valid?('sphinx')
  class Node
    include Bricks::Sphinx::NodeSearch
  end
else
  puts "## Not using sphinx for search: #{error}"
  Bricks::CONFIG.delete('sphinx')
end