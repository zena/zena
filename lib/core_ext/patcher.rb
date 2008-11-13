def foreach_plugin(&block)
  plugins_folder = File.join(RAILS_ROOT, 'vendor', 'plugins')
  Dir.foreach(plugins_folder) do |plugin|
    next if plugin =~ /\A\./
    block.call(File.join(plugins_folder, plugin))
  end
end

def load_patches_from_plugins
  file_name = caller[0].split('/').last.split(':').first
  foreach_plugin do |plugin_path|
    patch_file = File.join(plugin_path, 'patch', file_name)
    if File.exist?(patch_file)
      load patch_file
    end
  end
end

def load_models_from_plugins
  foreach_plugin do |plugin_path|
    models_path = File.join(plugin_path, 'models')
    next unless File.exist?(models_path)
    Dir.foreach(models_path) do |model_name|
      next if model_name =~ /\A\./
      load File.join(models_path, model_name)
    end
  end
end