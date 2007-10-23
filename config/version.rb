module Zena #:nodoc:
  module VERSION #:nodoc:
    MAJOR = 0
    MINOR = 8
    TINY  = 2
    REV   = ' rev 764+' # it would be nice to have this set during pre-commit hook
    STRING = [MAJOR, MINOR, TINY].join('.')
  end
end
