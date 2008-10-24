module Recaptcha #:nodoc:
  module VERSION #:nodoc:
    MAJOR = 0
    MINOR = 1
    TINY = (`hg parents`.split(/:/)[1]).strip

    STRING = [MAJOR, MINOR, TINY].join('.')
  end
end
