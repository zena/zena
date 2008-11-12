module Zena
  # This exception occurs when we have configuration problems.
  class BadConfiguration < Exception
  end
end

load_patches_from_plugins