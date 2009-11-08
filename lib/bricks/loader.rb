module Bricks
  module Loader
    def bricks
      @@bricks ||= bricks_folders.map do |bricks_folder|
        if File.exist?(bricks_folder)
          Dir.entries(bricks_folder).sort.map do |brick|
            if Bricks::CONFIG[brick]
              File.join(bricks_folder, brick)
            else
              nil
            end
          end
        else
          nil
        end
      end.flatten.compact.uniq
    end

    def bricks_folders
      @@bricks_folders ||= [File.join(Zena::ROOT, 'bricks'), File.join(RAILS_ROOT, 'bricks')].uniq.reject do |f|
        !File.exist?(f)
      end
    end

    def models_paths
      bricks.map {|f| Dir["#{f}/models"] }.flatten
    end

    def libs_paths
      bricks.map {|f| Dir["#{f}/lib"] }.flatten
    end

    def foreach_brick(&block)
      bricks.each do |path|
        block.call(path)
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

    def load_misc(filename)
      bricks.map {|f| Dir["#{f}/misc/#{filename}.rb"] }.flatten.each do |file|
        require file
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