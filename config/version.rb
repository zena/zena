module Zena #:nodoc:
  module VERSION #:nodoc:
    MAJOR = 0
    MINOR = 13
    TINY  = 0
    REV   = File.exist?(File.join(RAILS_ROOT, 'REVISION')) ? File.read(File.join(RAILS_ROOT, 'REVISION'))[0..5].to_i.to_s : '1330+'
    STRING = [MAJOR, MINOR, TINY].join('.')
  end
end
