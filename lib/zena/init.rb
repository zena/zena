# This is a dummy file to make mongrel happy when
# gem_plugin starts to do stupid things.
# The other solution would be for the gem_plugin to get fixed.
# See http://rubyforge.org/tracker/index.php?func=detail&aid=16145&group_id=1306&atid=5145
# 
=begin
----[ diff -u /usr/lib/ruby/gems/1.8/gems/gem_plugin-0.2.3/lib/gem_plugin.rb{~,} ]----
--- /usr/lib/ruby/gems/1.8/gems/gem_plugin-0.2.3/lib/gem_plugin.rb~     2007-12-06 17:34:58.000000000 +0100
+++ /usr/lib/ruby/gems/1.8/gems/gem_plugin-0.2.3/lib/gem_plugin.rb      2007-12-06 17:35:09.000000000 +0100
@@ -130,8 +130,9 @@
           # Previously was set wrong, we already have the correct gem path!
           #gem_dir = File.join(Gem.dir, "gems", "#{gem.name}-#{gem.version}")
           gem_dir = File.join(Gem.dir, "gems", path)
-
-          require File.join(gem_dir, "lib", gem.name, "init.rb")
+          init_rb = File.join(gem_dir, "lib", gem.name, "init.rb")
+
+          require init_rb if File.readable?(init_rb)
           @gems[gem.name] = gem_dir
         end
       end
=end
