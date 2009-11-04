require 'yaml'

module Bricks
  if File.exist?("#{RAILS_ROOT}/config/bricks.yml")
    raw_config = YAML.load_file("#{RAILS_ROOT}/config/bricks.yml")[RAILS_ENV] || {}
  else
    raw_config = YAML.load_file("#{Zena::ROOT}/config/bricks.yml")[RAILS_ENV] || {}
  end
  config = {}

  raw_config.each do |brick, opts|
    if opts.kind_of?(Hash)
      next unless opts['switch'] == true
      ok = true
      if required_gems = opts.delete('if_gem')
        required_gems.split(',').each do |name|
          begin
            require name
          rescue LoadError => err
            ok = false
            break
          end
        end
      end
      config[brick] = opts if ok
    else
      if opts == true
        config[brick] = {}
      end
    end
  end

  CONFIG = config

  class Patcher
    class << self
      def bricks_folders
        @bricks_folders ||= [File.join(Zena::ROOT, 'bricks'), File.join(RAILS_ROOT, 'bricks')].uniq.reject do |f|
          !File.exist?(f)
        end
      end

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

      def load_rake_tasks
        bricks.map {|f| Dir["#{f}/misc/tasks.rb"] }.flatten.each do |tasks_file|
          require tasks_file
        end
      end

      def load_deploy
        puts 'load_deploy'
        bricks.map {|f| Dir["#{f}/misc/deploy.rb"] }.flatten.each do |deploy_file|
          puts deploy_file
          require deploy_file
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