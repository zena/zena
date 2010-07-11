
if defined?(RAILS_ROOT)
  SITES_ROOT = "#{RAILS_ROOT}/sites"
end

AUTHENTICATED_PREFIX = "oo"
PASSWORD_SALT = "jf93jfnvnas09093nas0923" # type anything here (but change this line !)
ZENA_CALENDAR_LANGS = ["en", "fr", "de"] # FIXME: build this dynamically from existing files
ENABLE_XSENDFILE = false

module Zena
  VERSION = '0.16.7'
  REVISION = 1336
  ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
end