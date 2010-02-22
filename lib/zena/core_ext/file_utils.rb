# This file provides a portable way to symlink, reverting to copy if symlinks are not supported.

FileUtils

if RUBY_PLATFORM =~ /mswin32/
  class << FileUtils
    alias symlink_or_copy cp_r
  end
else
  class << FileUtils
    alias symlink_or_copy ln_s
  end
end