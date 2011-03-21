module Bricks
  module Loader
    @@no_init = false

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

    # Find all paths matching 'sub_path' in the active bricks.
    def paths_for(sub_path)
      bricks.map {|f| Dir["#{f}/#{sub_path}"] }.flatten
    end

    def models_paths
      paths_for('models')
    end

    def init_paths
      paths_for('zena/init.rb')
    end

    def migrations_for(brick)
      File.join(Zena::ROOT, 'bricks', brick, 'zena', 'migrate')
    end

    def fixtures_path_for(brick)
      File.join(Zena::ROOT, 'bricks', brick, 'zena', 'test', 'sites')
    end

    def zafu_tests
      paths_for('zena/test/zafu')
    end

    def test_files
      paths_for('zena/test/unit/*_test.rb') +
      paths_for('zena/test/functional/*_test.rb') +
      paths_for('zena/test/integration/*_test.rb')
     end

    # FIXME: remove
    def old_foreach_brick(&block)
      bricks.each do |path|
        block.call(path)
      end
    end

    # FIXME: remove
    def apply_patches(file_name = nil)
      file_name ||= caller[0].split('/').last.split(':').first
      old_foreach_brick do |brick_path|
        patch_file = File.join(brick_path, 'patch', file_name)
        if File.exist?(patch_file)
          load patch_file
        end
      end
    end

    def load_filename(filename)
      bricks.map {|f| Dir["#{f}/zena/#{filename}.rb"] }.flatten.each do |file|
        require file
      end
    end

    # FIXME: remove
    def load_zafu(mod)
      old_foreach_brick do |brick_path|
        brick_name = File.basename(brick_path)
        zafu_path  = File.join(brick_path, 'zafu')
        next unless File.exist?(zafu_path)
        Dir.foreach(zafu_path) do |rules_name|
          next if rules_name =~ /\A\./
          load File.join(zafu_path, rules_name)
        end
        mod.send(:include, eval("Bricks::#{brick_name.capitalize}::ZafuMethods"))
      end
    end

    def foreach_brick
      bricks.each do |path|
        yield File.basename(path)
      end
    end

    def no_init=(v)
      @@no_init = v
    end

    # Returns true if the Bricks code should not be executed (such
    # as during the initial migrations, legacy cleanup, etc).
    def no_init
      !Zena::Db.migrated_once? || @@no_init
    end

    def load_bricks
      bricks.each do |path|
        path = File.join(path, 'lib')
        ActiveSupport::Dependencies.autoload_paths      << path
        ActiveSupport::Dependencies.autoload_once_paths << path
        $LOAD_PATH                                  << path
      end

      if @@no_init
        puts "=> Not executing bricks init code."
        return
      end
      # load 'init'
      init_paths.each do |init_path|
        require init_path
      end
    end
  end
end