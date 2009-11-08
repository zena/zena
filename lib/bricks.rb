require File.join(File.dirname(__FILE__), '/bricks/requirements_validation')
require File.join(File.dirname(__FILE__), '/bricks/loader')

module Bricks
  extend Bricks::RequirementsValidation
  extend Bricks::Loader
  CONFIG = self.config_for_active_bricks
end

