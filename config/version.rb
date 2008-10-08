module Zena #:nodoc:
  module VERSION #:nodoc:
    MAJOR = 0
    MINOR = 10
    TINY  = 0
    REV   = File.exist?(File.join(RAILS_ROOT, 'REVISION')) ? File.read(File.join(RAILS_ROOT, 'REVISION'))[0..5] : '1217+'
    STRING = [MAJOR, MINOR, TINY].join('.')
  end
end
