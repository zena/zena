module Zena #:nodoc:
  module VERSION #:nodoc:
    MAJOR = 0
    MINOR = 11
    TINY  = 1
    REV   = File.exist?(File.join(RAILS_ROOT, 'REVISION')) ? File.read(File.join(RAILS_ROOT, 'REVISION'))[0..5].to_i.to_s : '1280+'
    STRING = [MAJOR, MINOR, TINY].join('.')
  end
end
