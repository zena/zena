module Bricks
  class Patcher
    class << self
      def bricks_folders
        @bricks_folders ||= [File.join(Zena::ROOT, 'bricks'), File.join(RAILS_ROOT, 'bricks')].uniq.reject {|f| !File.exist?(f)}
      end

      def models_paths
        bricks_folders.map {|f| Dir["#{f}/**/models"] }.flatten
      end

      def libs_paths
        bricks_folders.map {|f| Dir["#{f}/**/lib"] }.flatten
      end

      def foreach_brick(&block)
        bricks_folders.each do |bricks_folder|
          next unless File.exist?(bricks_folder)
          Dir.entries(bricks_folder).sort.each do |brick|
            next if brick =~ /\A\./
            block.call(File.join(bricks_folder, brick))
          end
        end
      end

      def apply_patches(file_name = nil)
        file_name ||= caller[0].split('/').last.split(':').first
        foreach_brick do |brick_path|
          patch_file = File.join(brick_path, 'patch', file_name)
          if File.exist?(patch_file)
            load patch_file
          end
        end
      end

      def load_bricks
        # load all libraries in bricks
        libs_paths.each do |lib_path|
          Dir.foreach(lib_path) do |f|
            next unless f =~ /\A.+\.rb\Z/
            require File.join(lib_path, f)
          end
        end

        # FIXME: do we really need to load these now, load_path isn't enough ?
        models_paths.each do |models_path|
          Dir.foreach(models_path) do |f|
            next unless f =~ /\A.+\.rb\Z/
            require File.join(models_path, f)
          end
        end
      end

      def load_zafu(mod)
        foreach_brick do |brick_path|
          brick_name = File.basename(brick_path)
          zafu_path  = File.join(brick_path, 'zafu')
          next unless File.exist?(zafu_path)
          Dir.foreach(zafu_path) do |rules_name|
            next if rules_name =~ /\A\./
            load File.join(zafu_path, rules_name)
          end
          mod.send(:include, eval("Bricks::#{brick_name.capitalize}::Zafu"))
        end
      end
    end
  end
end