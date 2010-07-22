# This file provides a portable way to symlink, reverting to copy if symlinks are not supported.

FileUtils

if FileUtils.send(:fu_have_symlink?)
  class << FileUtils
    alias symlink_or_copy ln_s
  end
else
  class << FileUtils
    alias symlink_or_copy cp_r
  end
end