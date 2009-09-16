module Bricks
  class Patcher
    class << self
      def foreach_brick(&block)
        bricks_folder = File.join(RAILS_ROOT, 'bricks')
        Dir.entries(bricks_folder).sort.each do |brick|
          next if brick =~ /\A\./
          block.call(File.join(bricks_folder, brick))
        end
      end

      def apply_patches
        file_name = caller[0].split('/').last.split(':').first
        foreach_brick do |brick_path|
          patch_file = File.join(brick_path, 'patch', file_name)
          if File.exist?(patch_file)
            load patch_file
          end
        end
      end

      def load_bricks
        # FIXME: replace this by extending 'load_path'
        foreach_brick do |brick_path|
          models_path = File.join(brick_path, 'models')
          next unless File.exist?(models_path)
          Dir.foreach(models_path) do |model_name|
            next if model_name =~ /\A\./
            eval model_name[/(\w+)\.rb/,1].capitalize.url_name
          end
        end

        # load all libraries in bricks
        foreach_brick do |brick_path|
          lib_path = File.join(brick_path, 'lib')
          next unless File.exist?(lib_path) && File.directory?(lib_path)
          Dir.foreach(lib_path) do |f|
            next unless f =~ /\A.+\.rb\Z/
            require File.join(lib_path, f)
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