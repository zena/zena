module Bricks
  RAW_CONFIG = if File.exist?("#{RAILS_ROOT}/config/bricks.yml")
    YAML.load_file("#{RAILS_ROOT}/config/bricks.yml")[RAILS_ENV] || {}
  else
    YAML.load_file("#{Zena::ROOT}/config/bricks.yml")[RAILS_ENV] || {}
  end
end