module Zena
  module Status
    # Redaction (initial state of an element)
    Red      = 70
    # Proposed along with another node (images/documents in the node)
    PropWith = 65
    # Proposed for publication
    Prop     = 60
    # Published
    Pub      = 50
    # Replaced (a new publication takes over)
    Rep      = 20
    # Removed (unpublished by hand)
    Rem      = 10
    # Deleted (not used)
    Del      = 0

    def self.[](key)
      self.const_get(key.to_s.camelize)
    end
  end # Status
end # Zena